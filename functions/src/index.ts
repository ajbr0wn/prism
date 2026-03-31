import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as Busboy from "busboy";

admin.initializeApp();

const LIBRARY_DOC = "users/default/library/state";
const ALLOWED_EXTENSIONS = [".epub", ".pdf"];

interface BookEntry {
  id: string;
  title: string;
  author: string;
  filePath: string;
  addedAt: string;
  coverPath: string | null;
  lastChapterIndex: number;
  lastScrollPosition: number;
  themeId: string | null;
  fileType: string;
  category: string;
  pageCount: number | null;
}

/**
 * HTTP endpoint that receives emails via SendGrid Inbound Parse.
 *
 * SendGrid sends a multipart/form-data POST with:
 * - `from`: sender email
 * - `subject`: email subject
 * - `text`: plain text body
 * - attachments as file fields
 *
 * Configure SendGrid Inbound Parse to POST to:
 *   https://<region>-<project>.cloudfunctions.net/receiveEmail
 */
export const receiveEmail = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  const busboy = Busboy({headers: req.headers});
  const uploads: Promise<void>[] = [];
  const newBooks: BookEntry[] = [];

  busboy.on("file", (fieldname: string, file: NodeJS.ReadableStream, info: {filename: string; encoding: string; mimeType: string}) => {
    const {filename} = info;
    const ext = filename.substring(filename.lastIndexOf(".")).toLowerCase();

    if (!ALLOWED_EXTENSIONS.includes(ext)) {
      file.resume(); // drain the stream
      return;
    }

    const timestamp = Date.now();
    const destFileName = `${timestamp}_book${ext}`;
    const storagePath = `books/${destFileName}`;

    const bucket = admin.storage().bucket();
    const fileRef = bucket.file(storagePath);
    const writeStream = fileRef.createWriteStream({
      metadata: {contentType: info.mimeType},
    });

    const upload = new Promise<void>((resolve, reject) => {
      file.pipe(writeStream);
      writeStream.on("finish", async () => {
        // Clean up the title from the filename
        const baseName = filename
          .substring(0, filename.lastIndexOf("."))
          .replace(/[_-]/g, " ")
          .replace(/\b\w/g, (c) => c.toUpperCase());

        const fileType = ext === ".pdf" ? "pdf" : "epub";
        // Auto-classify short PDFs or arxiv papers as academic papers
        const category = fileType === "pdf" &&
          (filename.toLowerCase().includes("arxiv") ||
           filename.toLowerCase().includes("paper"))
          ? "paper"
          : "book";

        const book: BookEntry = {
          id: timestamp.toString(),
          title: baseName,
          author: "Unknown Author",
          filePath: storagePath,
          addedAt: new Date().toISOString(),
          coverPath: null,
          lastChapterIndex: 0,
          lastScrollPosition: 0,
          themeId: null,
          fileType,
          category,
          pageCount: null,
        };

        newBooks.push(book);
        resolve();
      });
      writeStream.on("error", reject);
    });

    uploads.push(upload);
  });

  busboy.on("finish", async () => {
    try {
      await Promise.all(uploads);

      if (newBooks.length === 0) {
        res.status(200).send("No supported attachments found");
        return;
      }

      // Add to Firestore library
      const db = admin.firestore();
      const docRef = db.doc(LIBRARY_DOC);
      const doc = await docRef.get();

      let existingBooks: BookEntry[] = [];
      if (doc.exists) {
        const data = doc.data();
        existingBooks = (data?.books as BookEntry[]) || [];
      }

      // Prepend new books
      const updatedBooks = [...newBooks, ...existingBooks];

      await docRef.set({
        books: updatedBooks,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const titles = newBooks.map((b) => b.title).join(", ");
      console.log(`Added ${newBooks.length} book(s) to library: ${titles}`);
      res.status(200).send(`Added ${newBooks.length} book(s): ${titles}`);
    } catch (error) {
      console.error("Error processing email:", error);
      res.status(500).send("Internal error");
    }
  });

  busboy.end(req.rawBody);
});

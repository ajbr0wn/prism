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
 * With send_raw=false, SendGrid sends multipart/form-data with:
 * - text fields: from, subject, text, etc.
 * - attachment-info: JSON describing attachments
 * - file fields named by content-id or index for each attachment
 *
 * Configure SendGrid Inbound Parse to POST to:
 *   https://<region>-<project>.cloudfunctions.net/receiveEmail
 */
export const receiveEmail = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  console.log("Received inbound email");
  console.log("Content-Type:", req.headers["content-type"]);

  const busboy = Busboy({headers: req.headers});
  const uploads: Promise<void>[] = [];
  const newBooks: BookEntry[] = [];
  const fields: Record<string, string> = {};

  // Capture text fields (includes from, subject, attachment-info, etc.)
  busboy.on("field", (fieldname: string, val: string) => {
    fields[fieldname] = val;
    console.log(`Field: ${fieldname} = ${val.substring(0, 200)}`);
  });

  // Capture file uploads (attachments)
  busboy.on("file", (fieldname: string, file: NodeJS.ReadableStream, info: {filename: string; encoding: string; mimeType: string}) => {
    const filename = info.filename || fieldname;
    console.log(`File field: ${fieldname}, filename: ${filename}, type: ${info.mimeType}`);

    const ext = filename.includes(".")
      ? filename.substring(filename.lastIndexOf(".")).toLowerCase()
      : "";

    if (!ALLOWED_EXTENSIONS.includes(ext)) {
      console.log(`Skipping unsupported file: ${filename} (ext: ${ext})`);
      file.resume();
      return;
    }

    const timestamp = Date.now() + uploads.length; // unique per attachment
    const destFileName = `${timestamp}_book${ext}`;
    const storagePath = `books/${destFileName}`;

    const bucket = admin.storage().bucket();
    const fileRef = bucket.file(storagePath);
    const writeStream = fileRef.createWriteStream({
      metadata: {contentType: info.mimeType},
    });

    const upload = new Promise<void>((resolve, reject) => {
      file.pipe(writeStream);
      writeStream.on("finish", () => {
        const baseName = filename
          .substring(0, filename.lastIndexOf(".") >= 0 ? filename.lastIndexOf(".") : filename.length)
          .replace(/[_-]/g, " ")
          .replace(/\b\w/g, (c) => c.toUpperCase());

        const fileType = ext === ".pdf" ? "pdf" : "epub";
        const category = fileType === "pdf" &&
          (filename.toLowerCase().includes("arxiv") ||
           filename.toLowerCase().includes("paper"))
          ? "paper"
          : "book";

        const book: BookEntry = {
          id: timestamp.toString(),
          title: baseName || "Untitled",
          author: fields["from"] || "Unknown Author",
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
        console.log(`Uploaded: ${filename} -> ${storagePath}`);
        resolve();
      });
      writeStream.on("error", (err) => {
        console.error(`Upload failed for ${filename}:`, err);
        reject(err);
      });
    });

    uploads.push(upload);
  });

  busboy.on("finish", async () => {
    try {
      await Promise.all(uploads);

      console.log(`Processing complete. Fields: ${Object.keys(fields).join(", ")}. Files: ${newBooks.length}`);

      if (newBooks.length === 0) {
        console.log("No supported attachments found in email");
        res.status(200).send("No supported attachments found");
        return;
      }

      const db = admin.firestore();
      const docRef = db.doc(LIBRARY_DOC);
      const doc = await docRef.get();

      let existingBooks: BookEntry[] = [];
      if (doc.exists) {
        const data = doc.data();
        existingBooks = (data?.books as BookEntry[]) || [];
      }

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

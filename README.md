# Prism

A holographic e-reader for Android with real-time shader effects and deep visual theming.

## Features

- **EPUB and PDF reading** with full theme support
- **PDF reflow mode** — extracts text and re-renders it mobile-friendly with adjustable font size, margins, and spacing
- **LaTeX math rendering** — equations display natively in reflowed academic papers
- **12 built-in themes** with GLSL shader effects: holographic, aurora, opalescent, prismatic, ember, mandelbrot, julia, oil slick, voronoi, plasma
- **Books and Papers tabs** — PDFs auto-classify as academic papers or books
- **In-app links** — internal epub references and footnotes navigate correctly
- **Table of contents** — chapter list with tap-to-navigate
- **Highlights** — select text, pick a color, highlights persist per book
- **Per-book themes** and dark/light mode toggle
- **Reading progress sync** — chapter position and scroll offset saved automatically
- **Cloud library** — books and reading state persist across installs via Firebase
- **Cover art** extracted from EPUBs and rendered from PDF first pages

## Building

Requires Flutter 3.x, Android SDK, and Java 17.

```bash
flutter pub get
flutter build apk --release
```

## Architecture

- `lib/models/` — Book, theme, reading settings, highlights
- `lib/services/` — EPUB/PDF parsing, text extraction, reflow rendering, library sync
- `lib/screens/` — Library, EPUB reader, PDF reader, theme picker, settings
- `lib/widgets/` — Shader background, book cards
- `shaders/` — GLSL fragment shaders
- `functions/` — Cloud functions for backend processing

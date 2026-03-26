# Prism

An Android e-reader with deep visual theming and real-time shader effects. Inspired by the holographic/polychromatic aesthetic of Balatro.

## Features

- EPUB import and reading from device storage
- 8 built-in reading themes with distinct color palettes
- 5 GLSL fragment shader effects: holographic, aurora, opalescent, prismatic, ember
- Per-book theme assignment
- Reading progress persistence (chapter + scroll position)
- Cover art extraction and display
- Custom EPUB parser and XHTML renderer (no heavy dependencies)

## Building

Requires Flutter 3.x, Android SDK, and Java 17.

```bash
flutter pub get
flutter build apk --release
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Architecture

- `lib/models/`: Data models for books and themes
- `lib/services/`: EPUB parsing, library management, theme management, XHTML rendering
- `lib/screens/`: Library, reader, and theme picker UI
- `lib/widgets/`: Shader background, book cards
- `shaders/`: GLSL fragment shaders for visual effects

## Status

Early prototype. Known areas for improvement: theme selection UI, page-flip navigation, text formatting, shader realism.

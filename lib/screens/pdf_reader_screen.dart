import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/reading_settings.dart';
import '../models/reading_theme.dart';
import '../services/library_service.dart';
import '../services/pdf_reflow_renderer.dart';
import '../services/pdf_text_extractor.dart';
import '../services/reading_settings_service.dart';
import '../services/theme_service.dart';
import '../widgets/shader_background.dart';
import 'reading_settings_screen.dart';
import 'theme_picker_screen.dart';

class PdfReaderScreen extends StatefulWidget {
  final Book book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  bool _showControls = false;
  bool _reflowMode = false;
  late final PdfViewerController _pdfController;
  late final LibraryService _libraryService;
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  // Reflow state
  List<List<PdfContentBlock>>? _reflowContent;
  bool _reflowLoading = false;
  String? _reflowError;

  @override
  void initState() {
    super.initState();
    _libraryService = context.read<LibraryService>();
    _pdfController = PdfViewerController();
    _pdfController.addListener(_onViewChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pdfController.removeListener(_onViewChanged);
    super.dispose();
  }

  void _onViewChanged() {
    if (!_pdfController.isReady) return;
    _scrollOffset.value = _pdfController.visibleRect.top;
  }

  void _saveProgress() {
    if (_reflowMode) return; // Don't overwrite page-based progress in reflow mode
    if (!_pdfController.isReady) return;
    final pageNumber = _pdfController.pageNumber ?? 1;
    _libraryService.updateProgress(
      widget.book.id,
      chapterIndex: pageNumber - 1,
      scrollPosition: _pdfController.visibleRect.top,
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _toggleReflow() {
    setState(() {
      _reflowMode = !_reflowMode;
      _showControls = false;
    });
    if (_reflowMode && _reflowContent == null && !_reflowLoading) {
      _loadReflowContent();
    }
  }

  Future<void> _loadReflowContent() async {
    setState(() {
      _reflowLoading = true;
      _reflowError = null;
    });

    try {
      final doc = await PdfDocument.openFile(widget.book.filePath);
      final content = await PdfTextExtractor.extractDocument(doc);
      doc.dispose();

      if (mounted) {
        setState(() {
          _reflowContent = content;
          _reflowLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reflowError = e.toString();
          _reflowLoading = false;
        });
      }
    }
  }

  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThemePickerScreen(bookId: widget.book.id),
    );
  }

  void _openReadingSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReadingSettingsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final currentBook = library.books.cast<Book?>().firstWhere(
          (b) => b!.id == widget.book.id,
          orElse: () => widget.book,
        )!;
    final themeService = context.watch<ThemeService>();
    final baseTheme = themeService.getThemeForBook(currentBook.themeId);
    final settingsService = context.watch<ReadingSettingsService>();
    final readingSettings = settingsService.settings;
    final theme = baseTheme.withDarkMode(readingSettings.darkMode);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            theme.backgroundColor.computeLuminance() > 0.5
                ? Brightness.dark
                : Brightness.light,
        systemNavigationBarColor: theme.backgroundColor,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Container(color: theme.backgroundColor),

            // Shader
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (_, offset, __) => ShaderBackground(
                  theme: theme,
                  scrollOffset: offset,
                ),
              ),
            ),

            // Vignette
            if (theme.vignetteIntensity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black
                              .withValues(alpha: theme.vignetteIntensity),
                        ],
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

            // Content: either PDF page view or reflow view
            SafeArea(
              child: _reflowMode
                  ? _buildReflowView(theme, readingSettings)
                  : _buildPageView(),
            ),

            // Tap zones for controls
            if (!_showControls) ...[
              Positioned(
                top: 0, left: 0, right: 0, height: 60,
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 60,
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),
            ],

            // Controls overlay
            if (_showControls) ..._buildControls(theme, readingSettings, settingsService),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.translucent,
      child: PdfViewer.file(
        widget.book.filePath,
        controller: _pdfController,
        params: PdfViewerParams(
          backgroundColor: Colors.transparent,
          pageDropShadow: const BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
          enableTextSelection: true,
          scrollByMouseWheel: 1.0,
          onPageChanged: (pageNumber) {
            _saveProgress();
          },
        ),
      ),
    );
  }

  Widget _buildReflowView(ReadingTheme theme, ReadingSettings readingSettings) {
    if (_reflowLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.accentColor),
            SizedBox(height: readingSettings.fontSize),
            Text(
              'Extracting text...',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.5),
                fontSize: readingSettings.fontSize * 0.9,
              ),
            ),
          ],
        ),
      );
    }

    if (_reflowError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.accentColor),
              const SizedBox(height: 16),
              Text(
                'Could not extract text',
                style: TextStyle(color: theme.textColor, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _reflowError!,
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _toggleReflow,
                child: Text('Switch to page view',
                    style: TextStyle(color: theme.accentColor)),
              ),
            ],
          ),
        ),
      );
    }

    if (_reflowContent == null) {
      return const SizedBox.shrink();
    }

    final renderer = PdfReflowRenderer(
      theme: theme,
      settings: readingSettings,
    );
    final widgets = renderer.renderDocument(_reflowContent!);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (mounted) _scrollOffset.value = notification.metrics.pixels;
        }
        return false;
      },
      child: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: readingSettings.horizontalMargins,
              vertical: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widgets,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildControls(ReadingTheme theme, ReadingSettings readingSettings, ReadingSettingsService settingsService) {
    return [
      Positioned.fill(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
      ),

      // Top bar
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      _saveProgress();
                      Navigator.pop(context);
                    },
                  ),
                  // Reflow toggle
                  IconButton(
                    icon: Icon(
                      _reflowMode ? Icons.picture_as_pdf : Icons.article_outlined,
                      color: Colors.white, size: 22,
                    ),
                    onPressed: _toggleReflow,
                    tooltip: _reflowMode ? 'Page View' : 'Reflow View',
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.book.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _reflowMode ? 'Reflow View' : 'Page View',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_reflowMode)
                    IconButton(
                      icon: const Icon(Icons.text_fields,
                          color: Colors.white, size: 22),
                      onPressed: () {
                        _toggleControls();
                        _openReadingSettings();
                      },
                      tooltip: 'Reading Settings',
                    ),
                  IconButton(
                    icon: Icon(
                      readingSettings.darkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: Colors.white, size: 22,
                    ),
                    onPressed: () {
                      settingsService.update(readingSettings.copyWith(
                        darkMode: !readingSettings.darkMode,
                      ));
                    },
                    tooltip: readingSettings.darkMode ? 'Light Mode' : 'Dark Mode',
                  ),
                  IconButton(
                    icon: const Icon(Icons.palette_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () {
                      _toggleControls();
                      _openThemePicker();
                    },
                    tooltip: 'Theme',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Bottom bar with page info
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: _reflowMode
                    ? Text(
                        '${widget.book.pageCount ?? "?"} pages · Reflow',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      )
                    : ListenableBuilder(
                        listenable: _pdfController,
                        builder: (context, _) {
                          if (!_pdfController.isReady) {
                            return const SizedBox.shrink();
                          }
                          final page = _pdfController.pageNumber ?? 1;
                          final total = _pdfController.pageCount;
                          return Text(
                            'Page $page of $total',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

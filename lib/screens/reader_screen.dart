import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/highlight.dart';
import '../services/epub_renderer.dart';
import '../services/epub_service.dart';
import '../services/highlight_service.dart';
import '../services/library_service.dart';
import '../services/reading_settings_service.dart';
import '../services/theme_service.dart';
import '../widgets/shader_background.dart';
import 'highlights_screen.dart';
import 'reading_settings_screen.dart';
import 'theme_picker_screen.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  ParsedEpub? _epub;
  String? _error;
  int _currentChapter = 0;
  bool _showControls = false;

  // Scroll offset for the shader effect, isolated from widget rebuilds
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.book.lastChapterIndex;
    _pageController = PageController(initialPage: _currentChapter);
    _loadEpub();
    _loadHighlights();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollOffset.dispose();
    _saveProgress();
    super.dispose();
  }

  Future<void> _loadEpub() async {
    try {
      final epub = await EpubService.parse(widget.book.filePath);
      if (mounted) setState(() => _epub = epub);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadHighlights() async {
    await context.read<HighlightService>().loadHighlightsForBook(widget.book.id);
  }

  void _saveProgress() {
    context.read<LibraryService>().updateProgress(
          widget.book.id,
          chapterIndex: _currentChapter,
          scrollPosition: 0.0,
        );
  }

  void _onChapterChanged(int index) {
    _saveProgress();
    setState(() {
      _currentChapter = index;
    });
    _scrollOffset.value = 0.0;
  }

  void _goToChapter(int index) {
    if (index < 0 || _epub == null || index >= _epub!.chapters.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
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

  void _openHighlights() {
    if (_epub == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HighlightsScreen(
        bookId: widget.book.id,
        chapterTitles: _epub!.chapters.map((c) => c.title).toList(),
        onNavigate: (chapterIndex, paragraphIndex) {
          _goToChapter(chapterIndex);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch services for reactive updates
    final library = context.watch<LibraryService>();
    final currentBook = library.books.cast<Book?>().firstWhere(
          (b) => b!.id == widget.book.id,
          orElse: () => widget.book,
        )!;
    final themeService = context.watch<ThemeService>();
    final theme = themeService.getThemeForBook(currentBook.themeId);
    final settingsService = context.watch<ReadingSettingsService>();
    final readingSettings = settingsService.settings;
    final highlightService = context.watch<HighlightService>();

    if (_error != null) {
      return _buildErrorScreen(theme);
    }

    if (_epub == null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: theme.accentColor),
        ),
      );
    }

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
            // Layer 1: Solid background
            Container(color: theme.backgroundColor),

            // Layer 2: Shader effect (only rebuilds on scroll, not content)
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (_, offset, _) => ShaderBackground(
                theme: theme,
                scrollOffset: offset,
              ),
            ),

            // Layer 3: Vignette
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

            // Layer 4: Content
            SafeArea(
              child: readingSettings.continuousScroll
                  ? _buildContinuousScroll(
                      theme, readingSettings, highlightService)
                  : _buildPagedView(
                      theme, readingSettings, highlightService),
            ),

            // Layer 5: Controls
            if (_showControls) ..._buildControls(theme),
          ],
        ),
      ),
    );
  }

  /// Paged view: swipe left/right between chapters.
  Widget _buildPagedView(dynamic theme, dynamic readingSettings,
      HighlightService highlightService) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onChapterChanged,
      itemCount: _epub!.chapters.length,
      itemBuilder: (context, index) {
        return _buildChapterContent(
            index, theme, readingSettings, highlightService);
      },
    );
  }

  /// Continuous scroll: lazy-loaded chapters in one scrollable view.
  Widget _buildContinuousScroll(dynamic theme, dynamic readingSettings,
      HighlightService highlightService) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _scrollOffset.value = notification.metrics.pixels;
        }
        return false;
      },
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _epub!.chapters.length,
        itemBuilder: (context, index) {
          return _buildChapterContent(
              index, theme, readingSettings, highlightService);
        },
      ),
    );
  }

  Widget _buildChapterContent(int chapterIndex, dynamic theme,
      dynamic readingSettings, HighlightService highlightService) {
    final chapter = _epub!.chapters[chapterIndex];
    final chapterHighlights = highlightService.getHighlightsForChapter(
        widget.book.id, chapterIndex);

    final renderer = EpubRenderer(
      theme: theme,
      settings: readingSettings,
      chapterHighlights: chapterHighlights,
      onHighlight: (pIdx, start, end, text) {
        // Override chapter index for continuous scroll
        final highlight = Highlight(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          bookId: widget.book.id,
          chapterIndex: chapterIndex,
          paragraphIndex: pIdx,
          startOffset: start,
          endOffset: end,
          text: text,
          createdAt: DateTime.now(),
        );
        context.read<HighlightService>().addHighlight(highlight);
      },
    );
    final contentWidgets = renderer.render(chapter.content);

    final content = GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: readingSettings.horizontalMargins,
          vertical: 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets,
        ),
      ),
    );

    // In paged mode, each chapter is independently scrollable
    if (!readingSettings.continuousScroll) {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            _scrollOffset.value = notification.metrics.pixels;
          }
          return false;
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: content,
        ),
      );
    }

    return content;
  }

  List<Widget> _buildControls(dynamic theme) {
    return [
      // Tap to dismiss
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _epub!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _epub!.chapters[_currentChapter].title,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () {
                      _toggleControls();
                      _openHighlights();
                    },
                    tooltip: 'Highlights',
                  ),
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

      // Bottom bar
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _currentChapter > 0
                        ? () => _goToChapter(_currentChapter - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 20),
                    label: const Text('Prev'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      disabledForegroundColor: Colors.white24,
                    ),
                  ),
                  Text(
                    '${_currentChapter + 1} / ${_epub!.chapters.length}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  TextButton.icon(
                    onPressed:
                        _currentChapter < _epub!.chapters.length - 1
                            ? () => _goToChapter(_currentChapter + 1)
                            : null,
                    icon: const Text('Next'),
                    label: const Icon(Icons.chevron_right, size: 20),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      disabledForegroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildErrorScreen(dynamic theme) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.accentColor),
              const SizedBox(height: 16),
              Text(
                'Failed to open book',
                style: TextStyle(color: theme.textColor, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back',
                    style: TextStyle(color: theme.accentColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

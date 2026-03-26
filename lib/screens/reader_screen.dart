import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/epub_renderer.dart';
import '../services/epub_service.dart';
import '../services/library_service.dart';
import '../services/theme_service.dart';
import '../widgets/shader_background.dart';
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
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.book.lastChapterIndex;
    _loadEpub();
    _scrollController.addListener(_onScroll);

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Save progress
    _saveProgress();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _loadEpub() async {
    try {
      final epub = await EpubService.parse(widget.book.filePath);
      if (mounted) {
        setState(() => _epub = epub);
        // Restore scroll position after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(widget.book.lastScrollPosition);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _saveProgress() {
    context.read<LibraryService>().updateProgress(
          widget.book.id,
          chapterIndex: _currentChapter,
          scrollPosition: _scrollController.hasClients
              ? _scrollController.offset
              : 0.0,
        );
  }

  void _goToChapter(int index) {
    if (index < 0 || _epub == null || index >= _epub!.chapters.length) return;
    _saveProgress();
    setState(() {
      _currentChapter = index;
      _scrollOffset = 0.0;
    });
    _scrollController.jumpTo(0);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThemePickerScreen(book: widget.book),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final theme = themeService.getThemeForBook(widget.book.themeId);

    if (_error != null) {
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
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.5)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back', style: TextStyle(color: theme.accentColor)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_epub == null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: theme.accentColor),
        ),
      );
    }

    final chapter = _epub!.chapters[_currentChapter];
    final renderer = EpubRenderer(theme: theme);
    final contentWidgets = renderer.render(chapter.content);

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Layer 1: Solid background
            Container(color: theme.backgroundColor),

            // Layer 2: Shader effect
            ShaderBackground(
              theme: theme,
              scrollOffset: _scrollOffset,
            ),

            // Layer 3: Vignette overlay
            if (theme.vignetteIntensity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: theme.vignetteIntensity),
                        ],
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

            // Layer 4: Scrollable content
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: contentWidgets,
                  ),
                ),
              ),
            ),

            // Layer 5: Controls overlay
            if (_showControls) ...[
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
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  chapter.title,
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
                            icon: const Icon(Icons.palette_outlined, color: Colors.white),
                            onPressed: _openThemePicker,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom bar - chapter navigation
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
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                            onPressed: _currentChapter < _epub!.chapters.length - 1
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
            ],
          ],
        ),
      ),
    );
  }
}

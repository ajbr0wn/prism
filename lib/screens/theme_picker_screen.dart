import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/reading_theme.dart';
import '../services/library_service.dart';
import '../services/theme_service.dart';

class ThemePickerScreen extends StatelessWidget {
  final Book book;

  const ThemePickerScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final activeTheme = themeService.getThemeForBook(book.themeId);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141420),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Reading Theme',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Theme grid
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: themeService.allThemes.length,
                  itemBuilder: (context, index) {
                    final theme = themeService.allThemes[index];
                    final isActive = theme.id == activeTheme.id;

                    return _ThemeCard(
                      theme: theme,
                      isActive: isActive,
                      onTap: () => _applyTheme(context, theme),
                    );
                  },
                ),
              ),

              // Set as default option
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _setDefault(context, activeTheme),
                          child: Text(
                            'Set "${activeTheme.name}" as default for all books',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyTheme(BuildContext context, ReadingTheme theme) {
    context.read<LibraryService>().setBookTheme(book.id, theme.id);
  }

  void _setDefault(BuildContext context, ReadingTheme theme) {
    context.read<ThemeService>().setDefaultTheme(theme.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Default theme set to "${theme.name}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ReadingTheme theme;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? theme.accentColor : Colors.white12,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme name
              Text(
                theme.name,
                style: TextStyle(
                  color: theme.headingColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),

              // Sample text preview
              Text(
                'The quick brown fox jumps over the lazy dog.',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 10,
                  height: 1.4,
                  fontFamily: theme.fontFamily,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Effect indicator and color dots
              Row(
                children: [
                  if (theme.shaderEffect != ShaderEffect.none) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        theme.shaderEffect.name,
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  // Color dots
                  _colorDot(theme.textColor),
                  const SizedBox(width: 3),
                  _colorDot(theme.accentColor),
                  const SizedBox(width: 3),
                  _colorDot(theme.headingColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

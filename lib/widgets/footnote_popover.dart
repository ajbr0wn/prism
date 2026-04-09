import 'package:flutter/material.dart';

import '../models/reading_theme.dart';

/// A floating popover that displays footnote/citation content
/// without navigating away from the current reading position.
class FootnotePopover extends StatelessWidget {
  final String content;
  final ReadingTheme theme;
  final VoidCallback onDismiss;
  final VoidCallback? onNavigate;

  const FootnotePopover({
    super.key,
    required this.content,
    required this.theme,
    required this.onDismiss,
    this.onNavigate,
  });

  /// Show a footnote popover as a modal dialog.
  static Future<void> show({
    required BuildContext context,
    required String content,
    required ReadingTheme theme,
    VoidCallback? onNavigate,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss footnote',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return FootnotePopover(
          content: content,
          theme: theme,
          onDismiss: () => Navigator.of(context).pop(),
          onNavigate: onNavigate,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 16,
                        color: theme.accentColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Footnote',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (onNavigate != null)
                        GestureDetector(
                          onTap: () {
                            onDismiss();
                            onNavigate!();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Go to',
                              style: TextStyle(
                                color: theme.linkColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: onDismiss,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.textColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  height: 12,
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: SelectableText(
                      content,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

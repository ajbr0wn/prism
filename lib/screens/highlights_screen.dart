import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/highlight.dart';
import '../services/highlight_service.dart';

class HighlightsScreen extends StatelessWidget {
  final String bookId;
  final List<String> chapterTitles;
  final void Function(int chapterIndex, int paragraphIndex) onNavigate;

  const HighlightsScreen({
    super.key,
    required this.bookId,
    required this.chapterTitles,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final highlightService = context.watch<HighlightService>();
    final highlights = highlightService.getHighlightsForBook(bookId);

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

              // Title and count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Highlights',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${highlights.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              // Highlights list
              Expanded(
                child: highlights.isEmpty
                    ? _emptyState()
                    : _highlightList(context, highlights, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.highlight_outlined,
                size: 48, color: Colors.white12),
            SizedBox(height: 16),
            Text(
              'No highlights yet',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Long-press text while reading to highlight it',
              style: TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightList(BuildContext context, List<Highlight> highlights,
      ScrollController controller) {
    // Group by chapter
    final grouped = <int, List<Highlight>>{};
    for (final h in highlights) {
      grouped.putIfAbsent(h.chapterIndex, () => []).add(h);
    }
    final chapters = grouped.keys.toList()..sort();

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapterIdx = chapters[index];
        final chapterHighlights = grouped[chapterIdx]!;
        final title = chapterIdx < chapterTitles.length
            ? chapterTitles[chapterIdx]
            : 'Chapter ${chapterIdx + 1}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...chapterHighlights.map((h) => _highlightCard(context, h)),
          ],
        );
      },
    );
  }

  Widget _highlightCard(BuildContext context, Highlight highlight) {
    final color = Highlight.colors[highlight.colorIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          onNavigate(highlight.chapterIndex, highlight.paragraphIndex);
        },
        onLongPress: () =>
            _showHighlightOptions(context, highlight),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Text(
            highlight.text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _showHighlightOptions(BuildContext context, Highlight highlight) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Change color
              const Text('Change Color',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < Highlight.colors.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () {
                          context.read<HighlightService>().changeHighlightColor(
                              highlight.bookId, highlight.id, i);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Highlight.colors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == highlight.colorIndex
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Highlight',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  context
                      .read<HighlightService>()
                      .removeHighlight(highlight.bookId, highlight.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

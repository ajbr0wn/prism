import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading_settings.dart';
import '../services/reading_settings_service.dart';

class ReadingSettingsScreen extends StatelessWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ReadingSettingsService>();
    final s = service.settings;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141420),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Text(
                'Reading Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Font family
              _label('Font'),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (value, label) in ReadingSettings.fontOptions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _OptionChip(
                          label: label,
                          selected: s.fontFamily == value,
                          onTap: () => _update(
                              context, s.copyWith(fontFamily: value)),
                          minWidth: 64,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Font size
              _label('Size'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CircleButton(
                    icon: Icons.remove,
                    onTap: s.fontSize > 12
                        ? () => _update(
                            context, s.copyWith(fontSize: s.fontSize - 1))
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: s.fontSize,
                      min: 12,
                      max: 32,
                      divisions: 20,
                      activeColor: Colors.white54,
                      inactiveColor: Colors.white12,
                      onChanged: (v) =>
                          _update(context, s.copyWith(fontSize: v)),
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.add,
                    onTap: s.fontSize < 32
                        ? () => _update(
                            context, s.copyWith(fontSize: s.fontSize + 1))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${s.fontSize.round()}',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Line spacing
              _label('Line Spacing'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (value, label) in ReadingSettings.lineHeightOptions)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _OptionChip(
                          label: label,
                          selected: (s.lineHeight - value).abs() < 0.05,
                          onTap: () => _update(
                              context, s.copyWith(lineHeight: value)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Margins
              _label('Margins'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (value, label) in ReadingSettings.marginOptions)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _OptionChip(
                          label: label,
                          selected:
                              (s.horizontalMargins - value).abs() < 1.0,
                          onTap: () => _update(context,
                              s.copyWith(horizontalMargins: value)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Text alignment
              _label('Alignment'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (align, icon, label) in [
                    (TextAlign.start, Icons.format_align_left, 'Left'),
                    (TextAlign.center, Icons.format_align_center, 'Center'),
                    (TextAlign.justify, Icons.format_align_justify, 'Justify'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _OptionChip(
                          label: label,
                          icon: icon,
                          selected: s.textAlign == align,
                          onTap: () => _update(
                              context, s.copyWith(textAlign: align)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Dark mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        s.darkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Colors.white54, size: 18,
                      ),
                      const SizedBox(width: 8),
                      _label(s.darkMode ? 'Dark Mode' : 'Light Mode'),
                    ],
                  ),
                  Switch(
                    value: s.darkMode,
                    activeTrackColor: Colors.white38,
                    onChanged: (v) =>
                        _update(context, s.copyWith(darkMode: v)),
                  ),
                ],
              ),

              // Paragraph indent toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label('Paragraph Indent'),
                  Switch(
                    value: s.paragraphIndent,
                    activeTrackColor: Colors.white38,
                    onChanged: (v) =>
                        _update(context, s.copyWith(paragraphIndent: v)),
                  ),
                ],
              ),

              // Continuous scroll toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label('Continuous Scroll'),
                  Switch(
                    value: s.continuousScroll,
                    activeTrackColor: Colors.white38,
                    onChanged: (v) =>
                        _update(context, s.copyWith(continuousScroll: v)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  void _update(BuildContext context, ReadingSettings settings) {
    context.read<ReadingSettingsService>().update(settings);
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double? minWidth;

  const _OptionChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: minWidth != null
            ? BoxConstraints(minWidth: minWidth!)
            : const BoxConstraints(),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white30 : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white38,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? Colors.white54 : Colors.white12,
        ),
      ),
    );
  }
}

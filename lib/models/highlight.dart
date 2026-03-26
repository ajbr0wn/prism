import 'package:flutter/material.dart';

class Highlight {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final int startOffset;
  final int endOffset;
  final String text;
  final int colorIndex;
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.startOffset,
    required this.endOffset,
    required this.text,
    this.colorIndex = 2, // pink default
    required this.createdAt,
  });

  static const colors = [
    Color(0x60FFEB3B), // Yellow
    Color(0x5564B5F6), // Blue
    Color(0x55F48FB1), // Pink
    Color(0x55FFB74D), // Orange
  ];

  static const colorNames = ['Yellow', 'Blue', 'Pink', 'Orange'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'paragraphIndex': paragraphIndex,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'text': text,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        chapterIndex: json['chapterIndex'] as int,
        paragraphIndex: json['paragraphIndex'] as int,
        startOffset: json['startOffset'] as int,
        endOffset: json['endOffset'] as int,
        text: json['text'] as String,
        colorIndex: json['colorIndex'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

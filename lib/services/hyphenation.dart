/// English hyphenation engine.
///
/// Inserts Unicode soft hyphens (\u00AD) at valid syllable break points.
/// Soft hyphens are invisible until the text layout engine uses them
/// for line breaking, at which point they render as a regular hyphen.
/// This dramatically improves justified text spacing.
class Hyphenation {
  static final instance = Hyphenation._();
  Hyphenation._();

  // Cache: input text hashCode -> hyphenated result
  final Map<int, String> _cache = {};
  static const _maxCacheSize = 500;

  static const _softHyphen = '\u00AD';
  static const _minWordLength = 6;
  static const _minLeft = 2; // minimum chars before first break
  static const _minRight = 3; // minimum chars after last break

  static const _vowels = 'aeiouyAEIOUY';

  /// Process a full text string, hyphenating eligible words.
  /// Results are cached by text hash to avoid recomputing on re-renders.
  String process(String text) {
    final key = text.hashCode;
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = text.replaceAllMapped(
      RegExp(r"[a-zA-Z'\u2019]{6,}"),
      (match) {
        final word = match.group(0)!;
        if (word == word.toUpperCase() && word.length <= 6) return word;
        return hyphenateWord(word);
      },
    );

    // LRU-style cache: evict oldest when full
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
    return result;
  }

  /// Insert soft hyphens into a single word at valid break points.
  String hyphenateWord(String word) {
    if (word.length < _minWordLength) return word;

    final lower = word.toLowerCase();
    final breaks = <int>{};

    // 1. Suffix-based breaks (most reliable)
    _addSuffixBreaks(lower, breaks);

    // 2. Prefix-based breaks
    _addPrefixBreaks(lower, breaks);

    // 3. Consonant cluster breaks (VCCV rule)
    _addVCCVBreaks(lower, breaks);

    // 4. Single consonant breaks (VCV rule, less aggressive)
    _addVCVBreaks(lower, breaks);

    // Filter breaks that are too close to edges
    breaks.removeWhere(
        (b) => b < _minLeft || b > word.length - _minRight);

    if (breaks.isEmpty) return word;

    // Build the result
    final sorted = breaks.toList()..sort();
    final buf = StringBuffer();
    var prev = 0;
    for (final b in sorted) {
      buf.write(word.substring(prev, b));
      buf.write(_softHyphen);
      prev = b;
    }
    buf.write(word.substring(prev));
    return buf.toString();
  }

  void _addSuffixBreaks(String word, Set<int> breaks) {
    // (suffix, offset from suffix start where break goes)
    const suffixes = [
      // -tion, -sion family
      ('ation', 1),  // na-tion, cre-ation
      ('tion', 0),   // func-tion
      ('sion', 0),   // mis-sion
      // -ment
      ('ment', 0),   // mo-ment, achieve-ment
      // -ness
      ('ness', 0),   // dark-ness
      // -able, -ible
      ('able', 0),   // cap-able
      ('ible', 0),   // vis-ible
      // -ful, -less
      ('ful', 0),    // beauti-ful
      ('less', 0),   // hope-less
      // -ous
      ('eous', 1),   // gor-geous
      ('ious', 1),   // reli-gious
      ('ous', 0),    // fam-ous
      // -ive
      ('ative', 2),  // cre-ative
      ('itive', 2),  // prim-itive
      ('ive', 0),    // act-ive
      // -ing
      ('ting', 0),   // set-ting
      ('ning', 0),   // run-ning
      ('ring', 0),   // stir-ring
      ('ling', 0),   // trav-eling
      ('ing', 0),    // read-ing
      // -ence, -ance
      ('ence', 0),   // sci-ence
      ('ance', 0),   // dist-ance
      // -ity
      ('ity', 0),    // qual-ity
      // -ally, -ily
      ('ally', 0),   // actu-ally
      ('ily', 0),    // eas-ily
      // -ture
      ('ture', 0),   // na-ture
      // -ular
      ('ular', 1),   // pop-ular
      // -ical
      ('ical', 1),   // log-ical
      // -ious
      ('cious', 0),  // con-scious
      ('tious', 0),  // cau-tious
      // Other common endings
      ('ment', 0),
      ('ness', 0),
      ('ship', 0),   // friend-ship
      ('ward', 0),   // for-ward
      ('like', 0),   // life-like
      ('work', 0),   // frame-work
      ('land', 0),   // home-land
      ('ling', 0),   // dar-ling
    ];

    for (final (suffix, offset) in suffixes) {
      if (word.endsWith(suffix) && word.length > suffix.length + 2) {
        final breakPos = word.length - suffix.length + offset;
        if (breakPos >= _minLeft && breakPos <= word.length - _minRight) {
          breaks.add(breakPos);
        }
      }
    }
  }

  void _addPrefixBreaks(String word, Set<int> breaks) {
    const prefixes = [
      'under', 'super', 'inter', 'intro', 'extra',
      'over', 'anti', 'auto', 'semi', 'self',
      'dis', 'mis', 'non', 'pre', 'pro',
      'sub', 'out', 'mid',
      'un', 're',
    ];

    for (final prefix in prefixes) {
      if (word.startsWith(prefix) && word.length > prefix.length + 3) {
        // Verify the next char isn't the same as last prefix char
        // (avoid breaking "rre-" in "irrelevant")
        breaks.add(prefix.length);
        break; // only match one prefix
      }
    }
  }

  /// VCCV rule: break between two consonants when surrounded by vowels.
  /// Example: "struc-ture", "gar-den", "mon-ster"
  void _addVCCVBreaks(String word, Set<int> breaks) {
    for (var i = 1; i < word.length - 2; i++) {
      if (_isVowel(word[i]) &&
          _isConsonant(word[i + 1]) &&
          _isConsonant(word[i + 2]) &&
          i + 3 < word.length &&
          _isVowel(word[i + 3])) {
        // Don't break common digraphs
        final pair = word.substring(i + 1, i + 3);
        if (!_isDigraph(pair)) {
          breaks.add(i + 2); // break between the two consonants
        }
      }
    }
  }

  /// VCV rule: break before a single consonant between vowels.
  /// Example: "na-ture", "mo-ment" (less aggressive)
  void _addVCVBreaks(String word, Set<int> breaks) {
    for (var i = 1; i < word.length - 2; i++) {
      if (_isVowel(word[i]) &&
          _isConsonant(word[i + 1]) &&
          i + 2 < word.length &&
          _isVowel(word[i + 2])) {
        // Only add if no other break is nearby
        final pos = i + 1;
        final hasNearby = breaks.any((b) => (b - pos).abs() <= 2);
        if (!hasNearby) {
          breaks.add(pos);
        }
      }
    }
  }

  static bool _isVowel(String c) => _vowels.contains(c);
  static bool _isConsonant(String c) =>
      c.toLowerCase() != c.toUpperCase() && !_isVowel(c);

  /// Common consonant digraphs that shouldn't be split.
  static bool _isDigraph(String pair) {
    const digraphs = {
      'ch', 'sh', 'th', 'ph', 'wh', 'gh', 'ck',
      'ng', 'qu', 'bl', 'br', 'cl', 'cr', 'dr',
      'fl', 'fr', 'gl', 'gr', 'pl', 'pr', 'sc',
      'sk', 'sl', 'sm', 'sn', 'sp', 'st', 'sw',
      'tr', 'tw', 'wr',
    };
    return digraphs.contains(pair.toLowerCase());
  }
}

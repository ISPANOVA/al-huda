/// One printed line of the Madinah Mushaf (15 lines per page).
enum MushafLineType { header, basmala, text, centered }

class MushafWord {
  /// Global ayah number (1..6236) this word belongs to.
  final int ayah;

  /// The word in KFGQPC Hafs encoding. The last word of an ayah carries the
  /// ayah number after a no-break space (the font draws it as a medallion).
  final String text;

  const MushafWord(this.ayah, this.text);
}

class MushafLine {
  final MushafLineType type;

  /// Surah number for [MushafLineType.header].
  final int surah;

  /// Natural width of the line at font size 100 (words + minimal gaps).
  final double width100;

  final List<MushafWord> words;

  const MushafLine(this.type, {this.surah = 0, this.width100 = 0, this.words = const []});
}

import 'package:equatable/equatable.dart';

/// A saved position in the Quran (bookmark, favourite or last-read marker).
class AyahRef extends Equatable {
  final int surah;
  final int ayah;
  final String? text;
  final String? note;
  final DateTime savedAt;

  const AyahRef({required this.surah, required this.ayah, this.text, this.note, required this.savedAt});

  factory AyahRef.fromMap(Map<String, dynamic> m) => AyahRef(
        surah: (m['surah'] as num).toInt(),
        ayah: (m['ayah'] as num).toInt(),
        text: m['text'] as String?,
        note: m['note'] as String?,
        savedAt: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num?)?.toInt() ?? 0),
      );

  Map<String, dynamic> toMap() => {
        'surah': surah,
        'ayah': ayah,
        if (text != null) 'text': text,
        if (note != null) 'note': note,
        'ts': savedAt.millisecondsSinceEpoch,
      };

  bool sameAs(int s, int a) => surah == s && ayah == a;

  @override
  List<Object?> get props => [surah, ayah, note];
}

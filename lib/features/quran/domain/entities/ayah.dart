import 'package:equatable/equatable.dart';

class Ayah extends Equatable {
  /// Global number 1..6236.
  final int number;
  final int surah;
  final int numberInSurah;
  final String text;
  final String tafseer;
  final int juz;
  final int page;
  final bool sajda;

  /// 1..240 (quarter of hizb), 0 when unknown.
  final int hizbQuarter;

  const Ayah({
    required this.number,
    required this.surah,
    required this.numberInSurah,
    required this.text,
    required this.tafseer,
    required this.juz,
    required this.page,
    required this.sajda,
    this.hizbQuarter = 0,
  });

  int get hizb => hizbQuarter == 0 ? 0 : (hizbQuarter - 1) ~/ 4 + 1;

  /// 0..3 quarter within the hizb.
  int get quarterInHizb => hizbQuarter == 0 ? 0 : (hizbQuarter - 1) % 4;

  @override
  List<Object?> get props => [number, text, tafseer];
}

class SearchResult extends Equatable {
  final Ayah ayah;
  final String surahName;

  const SearchResult(this.ayah, this.surahName);

  @override
  List<Object?> get props => [ayah.number];
}

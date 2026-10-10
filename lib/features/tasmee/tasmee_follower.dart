import 'tasmee_engine.dart';

/// What the Tasmee page needs from whatever follows the reciter: the words
/// of the Mushaf with their states, where the reciter is, and the hints.
///
/// Two implementations: [TasmeeTracker] follows the words of a speech
/// recogniser (the browser's), [PhoneticTracker] follows the phonemes of the
/// on-device Quran model.
abstract class TasmeeFollower {
  List<TasmeeWord> get words;

  /// The place is known (found, or chosen by the reciter).
  bool get located;

  /// Where the reciter probably is before anything is found (the page they
  /// opened): preferred between equal places.
  int? get near;
  set near(int? value);

  /// Next word to recite.
  int get expected;
  bool get done;
  int get from;
  int get to;

  /// Starts at [index] (chosen by the reciter): words before it on the same
  /// page ([pageStart]) are shown as already read.
  void startAt(int index, {int? pageStart});

  /// Searches another range from now on (a chosen surah, or all).
  void setScope(int from, int to);

  /// The recogniser started over (a pause, or the microphone turned on).
  void newUtterance({bool manual = false});

  /// Shows the next word (a hint, not a mistake).
  void hintNext();

  /// Shows the rest of the current ayah.
  void revealAyah();
}

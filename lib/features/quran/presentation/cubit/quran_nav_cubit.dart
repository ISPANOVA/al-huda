import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A request to show the Mushaf at a position (switches to the Quran tab).
class QuranNavRequest extends Equatable {
  final int id;
  final int? page;
  final int? surah;
  final int? ayah;

  const QuranNavRequest({required this.id, this.page, this.surah, this.ayah});

  @override
  List<Object?> get props => [id, page, surah, ayah];
}

/// App-wide channel used by search, bookmarks, Khatmah, the dashboard… to open
/// the Mushaf tab at a given page/ayah instead of pushing a separate reader.
class QuranNavCubit extends Cubit<QuranNavRequest?> {
  QuranNavCubit() : super(null);

  int _id = 0;

  void openAt({int? page, int? surah, int? ayah}) =>
      emit(QuranNavRequest(id: ++_id, page: page, surah: surah, ayah: ayah));
}

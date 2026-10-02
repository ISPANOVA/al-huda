import '../../../core/services/storage_service.dart';
import '../domain/khatmah_plan.dart';

class KhatmahRepository {
  static const _key = 'plan';
  static const _khatmatKey = 'completed_khatmat';

  final StorageService _storage;

  KhatmahRepository(this._storage);

  KhatmahPlan? load() {
    final raw = _storage.khatmah.get(_key);
    if (raw == null) return null;
    try {
      return KhatmahPlan.fromMap(StorageService.asMap(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(KhatmahPlan plan) async {
    await _storage.khatmah.put(_key, plan.toMap());
    await _storage.khatmah.put(_khatmatKey, plan.completedKhatmat);
  }

  Future<void> delete() => _storage.khatmah.delete(_key);

  int get completedKhatmat => (_storage.khatmah.get(_khatmatKey) as num?)?.toInt() ?? 0;
}

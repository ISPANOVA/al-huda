import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/khatmah_repository.dart';
import '../../domain/khatmah_plan.dart';

class KhatmahState extends Equatable {
  final KhatmahPlan? plan;
  final int completedKhatmat;
  final bool justFinished;

  const KhatmahState({this.plan, this.completedKhatmat = 0, this.justFinished = false});

  @override
  List<Object?> get props => [plan, completedKhatmat, justFinished];
}

class KhatmahCubit extends Cubit<KhatmahState> {
  final KhatmahRepository _repo;
  final NotificationService _notifications;

  KhatmahCubit(this._repo, this._notifications)
      : super(KhatmahState(plan: _repo.load(), completedKhatmat: _repo.completedKhatmat));

  Future<void> _save(KhatmahPlan plan, {bool justFinished = false}) async {
    await _repo.save(plan);
    emit(KhatmahState(plan: plan, completedKhatmat: plan.completedKhatmat, justFinished: justFinished));
  }

  Future<void> createPlan({required int days, required bool reminder, int hour = 20, int minute = 0}) async {
    final plan = KhatmahPlan(
      startDate: DateTime.now(),
      targetDays: days.clamp(1, 365),
      reminderEnabled: reminder,
      reminderHour: hour,
      reminderMinute: minute,
      completedKhatmat: state.completedKhatmat,
    );
    await _save(plan);
    await _syncReminder(plan);
  }

  /// Sets the reading position to global ayah [global] (inclusive).
  Future<void> setProgress(int global) async {
    final plan = state.plan;
    if (plan == null) return;
    final target = global.clamp(0, KhatmahPlan.total);
    final delta = target - plan.completedAyahs;
    final today = KhatmahPlan.dayKey(DateTime.now());
    final history = Map<String, int>.of(plan.history);
    if (delta != 0) history[today] = ((history[today] ?? 0) + delta).clamp(0, KhatmahPlan.total);

    final finished = target >= KhatmahPlan.total && !plan.isFinished;
    final updated = plan.copyWith(
      completedAyahs: target,
      history: history,
      completedKhatmat: finished ? plan.completedKhatmat + 1 : plan.completedKhatmat,
    );
    await _save(updated, justFinished: finished);
  }

  Future<void> markTodayDone() async {
    final plan = state.plan;
    if (plan == null) return;
    await setProgress(plan.todayTo(DateTime.now()));
  }

  Future<void> updateReminder({required bool enabled, int? hour, int? minute}) async {
    final plan = state.plan;
    if (plan == null) return;
    final updated = plan.copyWith(reminderEnabled: enabled, reminderHour: hour, reminderMinute: minute);
    await _save(updated);
    await _syncReminder(updated);
  }

  /// Starts a fresh Khatmah with the same duration, keeping the completed count.
  Future<void> restart() async {
    final plan = state.plan;
    if (plan == null) return;
    await createPlan(
      days: plan.targetDays,
      reminder: plan.reminderEnabled,
      hour: plan.reminderHour,
      minute: plan.reminderMinute,
    );
  }

  Future<void> deletePlan() async {
    await _repo.delete();
    await _notifications.cancel(AppConstants.khatmahReminderId);
    emit(KhatmahState(completedKhatmat: state.completedKhatmat));
  }

  Future<void> _syncReminder(KhatmahPlan plan) async {
    await _notifications.cancel(AppConstants.khatmahReminderId);
    if (!plan.reminderEnabled || plan.isFinished) return;
    await _notifications.requestPermissions();
    await _notifications.scheduleDaily(
      id: AppConstants.khatmahReminderId,
      title: 'ورد الختمة اليومي 📖',
      body: 'حان وقت وردك من القرآن الكريم، واصل رحلتك نحو الختمة',
      hour: plan.reminderHour,
      minute: plan.reminderMinute,
    );
  }
}

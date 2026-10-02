import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../audio/presentation/cubit/audio_cubit.dart';
import '../../../audio/presentation/widgets/mini_player.dart';
import '../../../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../../domain/khatmah_plan.dart';
import '../cubit/khatmah_cubit.dart';

String describeGlobal(int global) {
  final r = SurahMetadata.fromGlobal(global);
  return 'سورة ${SurahMetadata.surah(r.surah).name} (${ArabicUtils.toArabicDigits(r.ayah)})';
}

class KhatmahPage extends StatelessWidget {
  const KhatmahPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const KhatmahPage());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'مخطط الختمة',
      bottom: const MiniPlayer(),
      body: BlocConsumer<KhatmahCubit, KhatmahState>(
        listenWhen: (p, c) => c.justFinished && !p.justFinished,
        listener: (context, state) => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('🎉 مبارك إتمام الختمة'),
            content: const Text(
              'اللهم ارحمني بالقرآن، واجعله لي إمامًا ونورًا وهدًى ورحمة. '
              'تقبل الله منك، ويمكنك بدء ختمة جديدة الآن.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('الحمد لله')),
            ],
          ),
        ),
        builder: (context, state) =>
            state.plan == null ? _SetupView(completedKhatmat: state.completedKhatmat) : _PlanView(plan: state.plan!),
      ),
    );
  }
}

class _SetupView extends StatefulWidget {
  final int completedKhatmat;

  const _SetupView({required this.completedKhatmat});

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  int _days = 30;
  bool _reminder = true;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  static const _presets = [7, 10, 15, 30, 60, 90];

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final perDay = (KhatmahPlan.total / _days).ceil();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassContainer(
          child: Column(
            children: [
              Icon(Icons.auto_stories_rounded, size: 56, color: glass.accent),
              const SizedBox(height: 10),
              Text('ابدأ ختمة جديدة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'حدد عدد الأيام وسنحسب وردك اليومي بدقة ونعدّله تلقائيًا إن تأخرت أو سبقت.',
                textAlign: TextAlign.center,
                style: TextStyle(color: glass.onGlassMuted, height: 1.6),
              ),
              if (widget.completedKhatmat > 0) ...[
                const SizedBox(height: 8),
                Text('ختماتك المكتملة: ${ArabicUtils.toArabicDigits(widget.completedKhatmat)}',
                    style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
        const GlassSectionTitle('مدة الختمة'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _presets)
              ChoiceChip(
                label: Text('${ArabicUtils.toArabicDigits(d)} يومًا'),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GlassContainer(
          child: Column(
            children: [
              Text('مدة مخصصة: ${ArabicUtils.toArabicDigits(_days)} يومًا'),
              Slider(value: _days.toDouble(), min: 3, max: 365, divisions: 362, onChanged: (v) => setState(() => _days = v.round())),
              Text(
                'الورد اليومي ≈ ${ArabicUtils.toArabicDigits(perDay)} آية '
                '(≈ ${ArabicUtils.toArabicDigits((604 / _days).toStringAsFixed(1))} صفحة)',
                style: TextStyle(fontWeight: FontWeight.w800, color: glass.accent),
              ),
            ],
          ),
        ),
        const GlassSectionTitle('التذكير اليومي'),
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تذكيري بالورد يوميًا'),
                value: _reminder,
                onChanged: (v) => setState(() => _reminder = v),
              ),
              if (_reminder)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm_rounded),
                  title: const Text('وقت التذكير'),
                  trailing: Text(_time.format(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => context
              .read<KhatmahCubit>()
              .createPlan(days: _days, reminder: _reminder, hour: _time.hour, minute: _time.minute),
          icon: const Icon(Icons.flag_rounded),
          label: const Text('ابدأ الختمة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _PlanView extends StatelessWidget {
  final KhatmahPlan plan;

  const _PlanView({required this.plan});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final now = DateTime.now();
    final cubit = context.read<KhatmahCubit>();
    final from = plan.todayFrom(now);
    final to = plan.todayTo(now);
    final delta = plan.scheduleDelta(now);
    final fromRef = SurahMetadata.fromGlobal(plan.isFinished ? 1 : (plan.completedAyahs + 1));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('التقدم الكلي',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text('${ArabicUtils.toArabicDigits((plan.progress * 100).toStringAsFixed(1))}٪',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: glass.accent)),
                ],
              ),
              const SizedBox(height: 10),
              GlassProgressBar(value: plan.progress, height: 14),
              const SizedBox(height: 10),
              Text(
                '${ArabicUtils.toArabicDigits(plan.completedAyahs)} من ${ArabicUtils.toArabicDigits(KhatmahPlan.total)} آية • '
                'اليوم ${ArabicUtils.toArabicDigits(plan.daysElapsed(now) + 1)} من ${ArabicUtils.toArabicDigits(plan.targetDays)}',
                style: TextStyle(color: glass.onGlassMuted),
              ),
              const SizedBox(height: 6),
              Text(
                delta >= 0
                    ? '✅ أنت متقدم على الجدول بـ ${ArabicUtils.toArabicDigits(delta)} آية'
                    : '⏳ متأخر عن الجدول بـ ${ArabicUtils.toArabicDigits(-delta)} آية، وسيُوزع الفرق على الأيام المتبقية',
                style: TextStyle(fontWeight: FontWeight.w700, color: delta >= 0 ? glass.accent : Colors.orange.shade300),
              ),
            ],
          ),
        ),
        const GlassSectionTitle('ورد اليوم'),
        if (plan.isFinished)
          MessageView(
            icon: Icons.celebration_rounded,
            title: 'أتممت الختمة، تقبل الله منك',
            subtitle: 'ختماتك المكتملة: ${ArabicUtils.toArabicDigits(plan.completedKhatmat)}',
            actionLabel: 'بدء ختمة جديدة',
            onAction: cubit.restart,
          )
        else
          GlassContainer(
            tint: plan.isTodayDone(now) ? glass.accent : null,
            opacity: plan.isTodayDone(now) ? 0.25 : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('من: ${describeGlobal(from)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text('إلى: ${describeGlobal(to)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                GlassProgressBar(value: plan.todayProgress(now)),
                const SizedBox(height: 6),
                Text(
                  plan.isTodayDone(now)
                      ? 'أحسنت! أتممت ورد اليوم 🌟'
                      : 'المتبقي اليوم: ${ArabicUtils.toArabicDigits(plan.todayRemaining(now))} آية',
                  style: TextStyle(color: glass.onGlassMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => MushafReaderPage.open(context, surah: fromRef.surah, ayah: fromRef.ayah),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('اقرأ'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final end = SurahMetadata.fromGlobal(to);
                          if (end.surah == fromRef.surah) {
                            context.read<AudioCubit>().playAyahs(fromRef.surah, fromRef.ayah, end.ayah);
                          } else {
                            context.read<AudioCubit>().playSurah(fromRef.surah, fromAyah: fromRef.ayah);
                          }
                        },
                        icon: const Icon(Icons.headphones_rounded),
                        label: const Text('استمع'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!plan.isTodayDone(now))
                  TextButton.icon(
                    onPressed: cubit.markTodayDone,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('أتممت ورد اليوم'),
                  ),
              ],
            ),
          ),
        const GlassSectionTitle('إعدادات الخطة'),
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('التذكير اليومي'),
                subtitle: Text(TimeOfDay(hour: plan.reminderHour, minute: plan.reminderMinute).format(context)),
                value: plan.reminderEnabled,
                onChanged: (v) => cubit.updateReminder(enabled: v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm_rounded),
                title: const Text('تغيير وقت التذكير'),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: plan.reminderHour, minute: plan.reminderMinute),
                  );
                  if (t != null) await cubit.updateReminder(enabled: true, hour: t.hour, minute: t.minute);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_location_alt_rounded),
                title: const Text('تعديل موضع التقدم يدويًا'),
                subtitle: const Text('أو من قائمة أي آية في المصحف: «تقدم الختمة»'),
                onTap: () => _editProgress(context, plan),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300),
                title: const Text('حذف الخطة'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف خطة الختمة؟'),
                      content: const Text('سيتم حذف التقدم الحالي لهذه الختمة.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (ok == true) await cubit.deletePlan();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editProgress(BuildContext context, KhatmahPlan plan) async {
    final current = SurahMetadata.fromGlobal(plan.completedAyahs == 0 ? 1 : plan.completedAyahs);
    var surah = current.surah;
    var ayah = current.ayah;
    final result = await showGlassSheet<int>(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final count = SurahMetadata.surah(surah).ayahCount;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('وصلت في القراءة إلى', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: surah,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'السورة'),
              items: [
                for (final s in SurahMetadata.all) DropdownMenuItem(value: s.number, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() {
                surah = v ?? surah;
                ayah = 1;
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: ValueKey(surah),
              initialValue: ayah.clamp(1, count),
              isExpanded: true,
              menuMaxHeight: 320,
              decoration: const InputDecoration(labelText: 'الآية'),
              items: [for (var a = 1; a <= count; a++) DropdownMenuItem(value: a, child: Text(ArabicUtils.toArabicDigits(a)))],
              onChanged: (v) => setState(() => ayah = v ?? ayah),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, SurahMetadata.globalAyah(surah, ayah)),
              child: const Text('حفظ'),
            ),
          ],
        );
      });
    });
    if (result != null && context.mounted) await context.read<KhatmahCubit>().setProgress(result);
  }
}

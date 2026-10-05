import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
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
      subtitle: 'ورد وتذكير',
      icon: Icons.flag_rounded,
      tone: Tone.gold,
      bottom: const MiniPlayer(),
      body: BlocConsumer<KhatmahCubit, KhatmahState>(
        listenWhen: (p, c) => c.justFinished && !p.justFinished,
        listener: (context, state) => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('مبارك إتمام الختمة'),
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

/// White-on-tone pill used on the solid hero cards.
class _HeroPill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final bool darker;

  const _HeroPill({this.icon, required this.text, this.darker = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: darker ? Colors.black.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row: coloured icon, title, subtitle and a switch, a trailing
/// widget or a chevron.
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final Color? titleColor;

  const _SettingRow({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.onTap,
    this.value,
    this.onChanged,
    this.trailing,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final toggle = value != null;
    return InkWell(
      onTap: toggle ? () => onChanged?.call(!value!) : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            ToneIcon(icon, tone: tone, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: titleColor ?? glass.onGlass)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, height: 1.4, color: glass.onGlassMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (toggle)
              Switch(value: value!, onChanged: onChanged)
            else
              trailing ?? Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
          ],
        ),
      ),
    );
  }
}

Widget _rows(BuildContext context, List<Widget> rows) {
  final glass = GlassTheme.of(context);
  return NoorCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 70, color: glass.onGlass.withValues(alpha: 0.08)),
          rows[i],
        ],
      ],
    ),
  );
}

/// Thin progress bar in a tone.
class _ToneBar extends StatelessWidget {
  final double value;
  final Tone tone;
  static const double height = 10;

  const _ToneBar({required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: glass.onGlass.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(height),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [tone.deep, tone.light]),
            ),
          ),
        ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final perDay = (KhatmahPlan.total / _days).ceil();
    const tone = Tone.gold;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ToneCard(
          tone: tone,
          solid: true,
          ornament: true,
          radius: 26,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.4),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'ابدأ ختمة جديدة',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'حدد عدد الأيام وسنحسب وردك اليومي بدقة ونعدّله تلقائيًا إن تأخرت أو سبقت.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.6),
              ),
              if (widget.completedKhatmat > 0) ...[
                const SizedBox(height: 12),
                _HeroPill(
                  icon: Icons.workspace_premium_rounded,
                  text: 'ختماتك المكتملة: ${ArabicUtils.toArabicDigits(widget.completedKhatmat)}',
                ),
              ],
            ],
          ),
        ),
        const GlassSectionTitle('مدة الختمة', tone: tone),
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
        const SizedBox(height: 12),
        NoorCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const ToneIcon(Icons.tune_rounded, tone: Tone.sapphire, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('مدة مخصصة: ${ArabicUtils.toArabicDigits(_days)} يومًا',
                        style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
                  ),
                ],
              ),
              Slider(value: _days.toDouble(), min: 3, max: 365, divisions: 362, onChanged: (v) => setState(() => _days = v.round())),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: tone.wash(dark),
                  border: Border.all(color: tone.mid.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الورد اليومي',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: glass.onGlassMuted)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('≈ ',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tone.ink(dark))),
                                Text(
                                  ArabicUtils.toArabicDigits(perDay),
                                  style: TextStyle(
                                    fontFamily: AppFonts.display,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    color: tone.ink(dark),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('آية',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: glass.onGlass)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: tone.mid.withValues(alpha: 0.35),
                    ),
                    Column(
                      children: [
                        Text(
                          '≈ ${ArabicUtils.toArabicDigits((604 / _days).toStringAsFixed(1))}',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: Tone.emerald.ink(dark),
                          ),
                        ),
                        Text('صفحة',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: glass.onGlassMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const GlassSectionTitle('التذكير اليومي', tone: tone),
        _rows(context, [
          _SettingRow(
            icon: Icons.notifications_active_rounded,
            tone: Tone.amber,
            title: 'تذكيري بالورد يوميًا',
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
          ),
          if (_reminder)
            _SettingRow(
              icon: Icons.alarm_rounded,
              tone: Tone.sapphire,
              title: 'وقت التذكير',
              trailing: Text(_time.format(context),
                  style: TextStyle(fontWeight: FontWeight.w800, color: tone.ink(dark))),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            ),
        ]),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final cubit = context.read<KhatmahCubit>();
    final from = plan.todayFrom(now);
    final to = plan.todayTo(now);
    final delta = plan.scheduleDelta(now);
    final fromRef = SurahMetadata.fromGlobal(plan.isFinished ? 1 : (plan.completedAyahs + 1));
    const tone = Tone.gold;
    const today = Tone.emerald;
    final todayDone = plan.isTodayDone(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ToneCard(
          tone: tone,
          solid: true,
          ornament: true,
          radius: 26,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NoorRing(
                    value: plan.progress,
                    color: Colors.white,
                    track: Colors.white.withValues(alpha: 0.22),
                    size: 108,
                    stroke: 9,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${ArabicUtils.toArabicDigits((plan.progress * 100).toStringAsFixed(1))}٪',
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('التقدم الكلي',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              ArabicUtils.toArabicDigits(plan.completedAyahs),
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Text('من ${ArabicUtils.toArabicDigits(KhatmahPlan.total)} آية',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _HeroPill(
                          icon: Icons.calendar_today_rounded,
                          text: 'اليوم ${ArabicUtils.toArabicDigits(plan.daysElapsed(now) + 1)} '
                              'من ${ArabicUtils.toArabicDigits(plan.targetDays)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _HeroPill(
                  darker: delta < 0,
                  text: delta >= 0
                      ? 'أنت متقدم على الجدول بـ ${ArabicUtils.toArabicDigits(delta)} آية'
                      : 'متأخر عن الجدول بـ ${ArabicUtils.toArabicDigits(-delta)} آية، وسيُوزع الفرق على الأيام المتبقية',
                ),
              ),
            ],
          ),
        ),
        const GlassSectionTitle('ورد اليوم', tone: today),
        if (plan.isFinished)
          MessageView(
            icon: Icons.celebration_rounded,
            title: 'أتممت الختمة، تقبل الله منك',
            subtitle: 'ختماتك المكتملة: ${ArabicUtils.toArabicDigits(plan.completedKhatmat)}',
            actionLabel: 'بدء ختمة جديدة',
            onAction: cubit.restart,
          )
        else
          ToneCard(
            tone: today,
            ornament: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PortionLine(label: 'من', text: describeGlobal(from), tone: today),
                const SizedBox(height: 8),
                _PortionLine(label: 'إلى', text: describeGlobal(to), tone: today),
                const SizedBox(height: 14),
                _ToneBar(value: plan.todayProgress(now), tone: today),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      todayDone ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                      size: 17,
                      color: todayDone ? today.ink(dark) : glass.onGlassMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        todayDone
                            ? 'أحسنت! أتممت ورد اليوم'
                            : 'المتبقي اليوم: ${ArabicUtils.toArabicDigits(plan.todayRemaining(now))} آية',
                        style: TextStyle(
                          color: todayDone ? today.ink(dark) : glass.onGlassMuted,
                          fontWeight: todayDone ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                if (!todayDone)
                  TextButton.icon(
                    onPressed: cubit.markTodayDone,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('أتممت ورد اليوم'),
                  ),
              ],
            ),
          ),
        const GlassSectionTitle('إعدادات الخطة', tone: tone),
        _rows(context, [
          _SettingRow(
            icon: Icons.notifications_active_rounded,
            tone: Tone.amber,
            title: 'التذكير اليومي',
            subtitle: TimeOfDay(hour: plan.reminderHour, minute: plan.reminderMinute).format(context),
            value: plan.reminderEnabled,
            onChanged: (v) => cubit.updateReminder(enabled: v),
          ),
          _SettingRow(
            icon: Icons.alarm_rounded,
            tone: Tone.sapphire,
            title: 'تغيير وقت التذكير',
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: plan.reminderHour, minute: plan.reminderMinute),
              );
              if (t != null) await cubit.updateReminder(enabled: true, hour: t.hour, minute: t.minute);
            },
          ),
          _SettingRow(
            icon: Icons.edit_location_alt_rounded,
            tone: Tone.teal,
            title: 'تعديل موضع التقدم يدويًا',
            subtitle: 'أو من قائمة أي آية في المصحف: «تقدم الختمة»',
            onTap: () => _editProgress(context, plan),
          ),
          _SettingRow(
            icon: Icons.delete_outline_rounded,
            tone: Tone.rose,
            title: 'حذف الخطة',
            titleColor: Tone.rose.ink(dark),
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
        ]),
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

/// «من / إلى» line of today's portion: a small tone label and the place.
class _PortionLine extends StatelessWidget {
  final String label;
  final String text;
  final Tone tone;

  const _PortionLine({required this.label, required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Row(
      children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: tone.solid),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: glass.onGlass)),
        ),
      ],
    );
  }
}

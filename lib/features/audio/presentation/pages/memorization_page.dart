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
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../domain/reciter.dart';
import '../cubit/audio_cubit.dart';
import '../cubit/audio_state.dart';
import '../widgets/mini_player.dart';

/// Memorization (Tahfeez) mode: custom range + per-ayah and range repetition.
class MemorizationPage extends StatefulWidget {
  const MemorizationPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const MemorizationPage());

  @override
  State<MemorizationPage> createState() => _MemorizationPageState();
}

class _MemorizationPageState extends State<MemorizationPage> {
  static const _tone = Tone.coral;

  int _startSurah = 1, _startAyah = 1, _endSurah = 1, _endAyah = 7;
  int _ayahRepeat = 3;
  int _rangeRepeat = 3;
  bool _infinite = false;
  late String _reciterId;

  @override
  void initState() {
    super.initState();
    _reciterId = context.read<SettingsCubit>().state.reciterId;
    final audio = context.read<AudioCubit>().state;
    if (audio.hasQueue && audio.surah != null) {
      _startSurah = _endSurah = audio.surah!;
      _startAyah = 1;
      _endAyah = SurahMetadata.surah(audio.surah!).ayahCount;
    }
  }

  int get _startGlobal => SurahMetadata.globalAyah(_startSurah, _startAyah);
  int get _endGlobal => SurahMetadata.globalAyah(_endSurah, _endAyah);
  bool get _valid => _endGlobal >= _startGlobal;

  Future<void> _start() async {
    if (!_valid) {
      showGlassSnack(context, 'نهاية النطاق يجب أن تكون بعد بدايته');
      return;
    }
    await context.read<AudioCubit>().playRange(
          PlaybackRange(
            startSurah: _startSurah,
            startAyah: _startAyah,
            endSurah: _endSurah,
            endAyah: _endAyah,
            ayahRepeat: _ayahRepeat,
            rangeRepeat: _infinite ? 0 : _rangeRepeat,
          ),
          reciter: Reciters.byId(_reciterId),
        );
    if (mounted) showGlassSnack(context, 'بدأت جلسة الحفظ، وفقك الله');
  }

  Future<void> _pickReciter() async {
    final id = await showReciterPicker(context, _reciterId);
    if (id != null) setState(() => _reciterId = id);
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final total = _valid ? _endGlobal - _startGlobal + 1 : 0;
    final divider = Divider(height: 1, indent: 52, color: glass.onGlass.withValues(alpha: 0.08));
    return GlassScaffold(
      title: 'وضع الحفظ والتكرار',
      subtitle: 'حدّد النطاق وعدد التكرار ثم ابدأ',
      icon: Icons.repeat_on_rounded,
      tone: _tone,
      bottom: const MiniPlayer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SummaryHero(
            startSurah: _startSurah,
            startAyah: _startAyah,
            endSurah: _endSurah,
            endAyah: _endAyah,
            valid: _valid,
            total: total,
            ayahRepeat: _ayahRepeat,
            rangeRepeat: _rangeRepeat,
            infinite: _infinite,
          ),

          // ------------------------------------------------------- range ---
          const GlassSectionTitle('النطاق', tone: _tone),
          _RangeTile(
            label: 'بداية النطاق',
            icon: Icons.flag_rounded,
            tone: Tone.emerald,
            surah: _startSurah,
            ayah: _startAyah,
            onChanged: (s, a) => setState(() {
              _startSurah = s;
              _startAyah = a;
              if (!_valid) {
                _endSurah = s;
                _endAyah = SurahMetadata.surah(s).ayahCount;
              }
            }),
          ),
          const SizedBox(height: 12),
          _RangeTile(
            label: 'نهاية النطاق',
            icon: Icons.sports_score_rounded,
            tone: Tone.sapphire,
            surah: _endSurah,
            ayah: _endAyah,
            onChanged: (s, a) => setState(() {
              _endSurah = s;
              _endAyah = a;
            }),
          ),

          // ------------------------------------------------------ repeat ---
          const GlassSectionTitle('التكرار', tone: _tone),
          NoorCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PillStepper(
                  label: 'تكرار كل آية',
                  hint: 'عدد مرات إعادة الآية الواحدة',
                  icon: Icons.repeat_one_rounded,
                  tone: Tone.amber,
                  value: _ayahRepeat,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() => _ayahRepeat = v),
                ),
                divider,
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _infinite = !_infinite),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const ToneIcon(Icons.all_inclusive_rounded, tone: Tone.teal, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تكرار النطاق بلا توقف',
                                  maxLines: 2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              Text('يُعاد النطاق حتى تُوقفه بنفسك',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                            ],
                          ),
                        ),
                        Switch(value: _infinite, onChanged: (v) => setState(() => _infinite = v)),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _infinite
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            divider,
                            _PillStepper(
                              label: 'تكرار النطاق كاملًا',
                              hint: 'عدد مرات إعادة النطاق من أوله',
                              icon: Icons.replay_rounded,
                              tone: _tone,
                              value: _rangeRepeat,
                              min: 1,
                              max: 50,
                              onChanged: (v) => setState(() => _rangeRepeat = v),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------- reciter ---
          const GlassSectionTitle('القارئ', tone: Tone.amethyst),
          ToneCard(
            tone: Tone.amethyst,
            radius: 22,
            padding: const EdgeInsets.all(14),
            onTap: _pickReciter,
            child: Row(
              children: [
                const ToneIcon(Icons.record_voice_over_rounded, tone: Tone.amethyst, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('القارئ', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                      Text(Reciters.byId(_reciterId).nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Tone.amethyst.mid.withValues(alpha: dark ? 0.18 : 0.12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('تغيير',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800, color: Tone.amethyst.ink(dark))),
                      Icon(Icons.chevron_left_rounded, size: 20, color: Tone.amethyst.ink(dark)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('ابدأ جلسة الحفظ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 16),
          BlocBuilder<AudioCubit, AudioState>(
            buildWhen: (p, c) =>
                p.isMemorization != c.isMemorization ||
                p.title != c.title ||
                p.loopsRemaining != c.loopsRemaining ||
                p.queueIndex != c.queueIndex,
            builder: (context, audio) {
              if (!audio.hasQueue || !audio.isMemorization) return const SizedBox.shrink();
              return ToneCard(
                tone: _tone,
                ornament: true,
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const ToneIcon(Icons.graphic_eq_rounded, tone: _tone, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الجلسة الحالية',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                              Text(audio.title ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ToneBar(
                      value: audio.queueLength == 0 ? 0 : (audio.queueIndex + 1) / audio.queueLength,
                      tone: _tone,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      audio.infiniteLoop
                          ? 'تكرار مستمر للنطاق'
                          : 'التكرارات المتبقية للنطاق: ${ArabicUtils.toArabicDigits(audio.loopsRemaining)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _tone.ink(dark)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Solid coral card at the top: the chosen range and the repeat counts.
class _SummaryHero extends StatelessWidget {
  final int startSurah, startAyah, endSurah, endAyah;
  final bool valid;
  final int total;
  final int ayahRepeat;
  final int rangeRepeat;
  final bool infinite;

  const _SummaryHero({
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
    required this.valid,
    required this.total,
    required this.ayahRepeat,
    required this.rangeRepeat,
    required this.infinite,
  });

  static String _ayatWord(int n) {
    if (n == 1) return 'آية واحدة';
    if (n == 2) return 'آيتان';
    final d = ArabicUtils.toArabicDigits(n);
    return n >= 3 && n <= 10 ? '$d آيات' : '$d آية';
  }

  @override
  Widget build(BuildContext context) {
    final d = ArabicUtils.toArabicDigits;
    final from = SurahMetadata.surah(startSurah).name;
    final to = SurahMetadata.surah(endSurah).name;
    return ToneCard(
      tone: Tone.coral,
      solid: true,
      ornament: true,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                child: const Icon(Icons.repeat_on_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('ملخص الجلسة',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'من $from ${d(startAyah)} إلى $to ${d(endAyah)}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (valid)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(icon: Icons.format_list_numbered_rounded, text: _ayatWord(total)),
                _HeroPill(icon: Icons.repeat_one_rounded, text: 'كل آية ${d(ayahRepeat)}×'),
                _HeroPill(
                  icon: infinite ? Icons.all_inclusive_rounded : Icons.replay_rounded,
                  text: infinite ? 'النطاق بلا توقف' : 'النطاق ${d(rangeRepeat)}×',
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.22),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('النهاية قبل البداية، يرجى تعديل النطاق',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 12, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// One end of the range: a tone tile with the surah and ayah pickers.
class _RangeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Tone tone;
  final int surah;
  final int ayah;
  final void Function(int surah, int ayah) onChanged;

  const _RangeTile({
    required this.label,
    required this.icon,
    required this.tone,
    required this.surah,
    required this.ayah,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return ToneCard(
      tone: tone,
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ToneIcon(icon, tone: tone, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(
                      'سورة ${SurahMetadata.surah(surah).name} • الآية ${ArabicUtils.toArabicDigits(ayah)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AyahPicker(surah: surah, ayah: ayah, tone: tone, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AyahPicker extends StatelessWidget {
  final int surah;
  final int ayah;
  final Tone tone;
  final void Function(int surah, int ayah) onChanged;

  const _AyahPicker({required this.surah, required this.ayah, required this.tone, required this.onChanged});

  InputDecoration _decoration(BuildContext context, String label) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(double alpha, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tone.mid.withValues(alpha: alpha), width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: glass.onGlassMuted),
      floatingLabelStyle: TextStyle(color: tone.ink(dark), fontWeight: FontWeight.w800),
      filled: true,
      fillColor: tone.mid.withValues(alpha: dark ? 0.10 : 0.07),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(0.35, 1),
      enabledBorder: border(0.35, 1),
      focusedBorder: border(0.9, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = SurahMetadata.surah(surah).ayahCount;
    final iconColor = tone.ink(dark);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: surah,
            isExpanded: true,
            iconEnabledColor: iconColor,
            borderRadius: BorderRadius.circular(18),
            decoration: _decoration(context, 'السورة'),
            items: [
              for (final s in SurahMetadata.all)
                DropdownMenuItem(value: s.number, child: Text('${ArabicUtils.toArabicDigits(s.number)}. ${s.name}')),
            ],
            onChanged: (v) => v == null ? null : onChanged(v, 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            key: ValueKey('ayah-$surah'),
            initialValue: ayah.clamp(1, count),
            isExpanded: true,
            iconEnabledColor: iconColor,
            borderRadius: BorderRadius.circular(18),
            decoration: _decoration(context, 'الآية'),
            menuMaxHeight: 360,
            items: [
              for (var a = 1; a <= count; a++) DropdownMenuItem(value: a, child: Text(ArabicUtils.toArabicDigits(a))),
            ],
            onChanged: (v) => v == null ? null : onChanged(surah, v),
          ),
        ),
      ],
    );
  }
}

/// A row with the tone icon, the label and a pill of −/count/+ buttons.
class _PillStepper extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Tone tone;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _PillStepper({
    required this.label,
    required this.hint,
    required this.icon,
    required this.tone,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ToneIcon(icon, tone: tone, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: tone.mid.withValues(alpha: dark ? 0.14 : 0.10),
              border: Border.all(color: tone.mid.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  tone: tone,
                  onTap: value > min ? () => onChanged(value - 1) : null,
                ),
                SizedBox(
                  width: 54,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${ArabicUtils.toArabicDigits(value)}×',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: tone.ink(dark),
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  tone: tone,
                  onTap: value < max ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient()),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 36, child: Icon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar in a tone.
class _ToneBar extends StatelessWidget {
  final double value;
  final Tone tone;

  const _ToneBar({required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: tone.mid.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: [tone.light, tone.deep]),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

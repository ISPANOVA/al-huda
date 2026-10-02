import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
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

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final total = _valid ? _endGlobal - _startGlobal + 1 : 0;
    return GlassScaffold(
      title: 'وضع الحفظ والتكرار',
      bottom: const MiniPlayer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GlassSectionTitle('بداية النطاق'),
                _AyahPicker(
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
                const GlassSectionTitle('نهاية النطاق'),
                _AyahPicker(
                  surah: _endSurah,
                  ayah: _endAyah,
                  onChanged: (s, a) => setState(() {
                    _endSurah = s;
                    _endAyah = a;
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  _valid
                      ? 'عدد الآيات في النطاق: ${ArabicUtils.toArabicDigits(total)}'
                      : '⚠️ النهاية قبل البداية، يرجى تعديل النطاق',
                  style: TextStyle(color: _valid ? glass.onGlassMuted : Colors.red.shade300),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stepper(
                  label: 'تكرار كل آية',
                  value: _ayahRepeat,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() => _ayahRepeat = v),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تكرار النطاق بلا توقف'),
                  value: _infinite,
                  onChanged: (v) => setState(() => _infinite = v),
                ),
                if (!_infinite)
                  _Stepper(
                    label: 'تكرار النطاق كاملًا',
                    value: _rangeRepeat,
                    min: 1,
                    max: 50,
                    onChanged: (v) => setState(() => _rangeRepeat = v),
                  ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.record_voice_over_rounded, color: glass.accent),
                  title: const Text('القارئ'),
                  subtitle: Text(Reciters.byId(_reciterId).nameAr),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () async {
                    final id = await showReciterPicker(context, _reciterId);
                    if (id != null) setState(() => _reciterId = id);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
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
              return GlassContainer(
                tint: glass.accent,
                opacity: 0.22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('الجلسة الحالية', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(audio.title ?? ''),
                    const SizedBox(height: 8),
                    GlassProgressBar(value: audio.queueLength == 0 ? 0 : (audio.queueIndex + 1) / audio.queueLength),
                    const SizedBox(height: 6),
                    Text(
                      audio.infiniteLoop
                          ? 'تكرار مستمر للنطاق'
                          : 'التكرارات المتبقية للنطاق: ${ArabicUtils.toArabicDigits(audio.loopsRemaining)}',
                      style: TextStyle(color: glass.onGlassMuted),
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

class _AyahPicker extends StatelessWidget {
  final int surah;
  final int ayah;
  final void Function(int surah, int ayah) onChanged;

  const _AyahPicker({required this.surah, required this.ayah, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final count = SurahMetadata.surah(surah).ayahCount;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: surah,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'السورة'),
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
            decoration: const InputDecoration(labelText: 'الآية'),
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

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          width: 48,
          alignment: Alignment.center,
          child: Text('${ArabicUtils.toArabicDigits(value)}×',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: glass.accent)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../audio/domain/reciter.dart';
import '../../../audio/presentation/cubit/audio_cubit.dart';
import '../../../audio/presentation/widgets/mini_player.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../domain/entities/ayah.dart';

/// "استماع" choices: this ayah only, to the end of the surah, or a custom
/// passage with reciter and repetition (memorization).
Future<void> showListenOptions(BuildContext context, Ayah ayah) {
  return showGlassSheet<void>(context, builder: (ctx) => _ListenSheet(ayah: ayah, host: context));
}

class _ListenSheet extends StatefulWidget {
  final Ayah ayah;
  final BuildContext host;

  const _ListenSheet({required this.ayah, required this.host});

  @override
  State<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends State<_ListenSheet> {
  bool _custom = false;
  late int _surah = widget.ayah.surah;
  late int _from = widget.ayah.numberInSurah;
  late int _to = widget.ayah.numberInSurah;
  late String _reciter = widget.host.read<SettingsCubit>().state.reciterId;
  int _ayahRepeat = 1;
  int _rangeRepeat = 1;

  static const _ayahRepeats = [1, 2, 3, 5, 7, 10];
  static const _rangeRepeats = [1, 2, 3, 5, 10, 0]; // 0 = بلا توقف

  int get _count => SurahMetadata.surah(_surah).ayahCount;

  AudioCubit get _audio => widget.host.read<AudioCubit>();

  void update(VoidCallback fn) => setState(fn);

  /// Picks the reciter for every option below and remembers it app-wide.
  Future<void> pickReciter() async {
    final id = await showReciterPicker(context, _reciter);
    if (id == null || !mounted) return;
    setState(() => _reciter = id);
    await widget.host.read<SettingsCubit>().setReciter(id);
  }

  void _done() => Navigator.of(context).pop();

  void _playThisAyah() {
    _done();
    _audio.playRange(
      PlaybackRange(
        startSurah: widget.ayah.surah,
        startAyah: widget.ayah.numberInSurah,
        endSurah: widget.ayah.surah,
        endAyah: widget.ayah.numberInSurah,
      ),
      reciter: Reciters.byId(_reciter),
    );
  }

  void _playToEnd() {
    _done();
    _audio.playSurah(widget.ayah.surah, fromAyah: widget.ayah.numberInSurah);
  }

  void _playCustom() {
    _done();
    _audio.playRange(
      PlaybackRange(
        startSurah: _surah,
        startAyah: _from,
        endSurah: _surah,
        endAyah: _to,
        ayahRepeat: _ayahRepeat,
        rangeRepeat: _rangeRepeat,
      ),
      reciter: Reciters.byId(_reciter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final title = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
      child: SingleChildScrollView(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الاستماع', style: title, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'سورة ${SurahMetadata.surah(widget.ayah.surah).name} • الآية ${ArabicUtils.toArabicDigits(widget.ayah.numberInSurah)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: glass.onGlassMuted),
              ),
              const SizedBox(height: 12),
              _ReciterTile(state: this),
              const SizedBox(height: 10),
              _Option(
                icon: Icons.looks_one_rounded,
                title: 'هذه الآية فقط',
                subtitle: 'تشغيل الآية مرة واحدة',
                onTap: _playThisAyah,
              ),
              _Option(
                icon: Icons.playlist_play_rounded,
                title: 'من هذه الآية حتى آخر السورة',
                subtitle: 'تلاوة متصلة',
                onTap: _playToEnd,
              ),
              _Option(
                icon: Icons.repeat_rounded,
                title: 'تحديد مقطع وتكرار',
                subtitle: 'من آية إلى آية، القارئ وعدد مرات التكرار',
                selected: _custom,
                onTap: () => setState(() => _custom = !_custom),
              ),
              if (_custom) ...[
                const SizedBox(height: 6),
                _CustomRange(state: this),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomRange extends StatelessWidget {
  final _ListenSheetState state;

  const _CustomRange({required this.state});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final s = state;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlassMuted)),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: glass.onGlass.withValues(alpha: 0.05),
        border: Border.all(color: glass.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('السورة'),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showGlassSheet<int>(context, builder: (ctx) => const _SurahPicker());
              if (picked != null) {
                s.update(() {
                  s._surah = picked;
                  s._from = 1;
                  s._to = SurahMetadata.surah(picked).ayahCount;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(Icons.expand_more_rounded)),
              child: Text('سورة ${SurahMetadata.surah(s._surah).name}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          label('من الآية إلى الآية'),
          Row(
            children: [
              Expanded(
                child: _Stepper(
                  value: s._from,
                  min: 1,
                  max: s._count,
                    onChanged: (v) => s.update(() {
                    s._from = v;
                    if (s._to < v) s._to = v;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_back_rounded, color: glass.onGlassMuted),
              ),
              Expanded(
                child: _Stepper(
                  value: s._to,
                  min: s._from,
                  max: s._count,
                    onChanged: (v) => s.update(() => s._to = v),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(s._from.toDouble(), s._to.toDouble()),
            min: 1,
            max: s._count.toDouble().clamp(1.0001, double.infinity),
            divisions: s._count > 1 ? s._count - 1 : null,
            onChanged: (r) => s.update(() {
              s._from = r.start.round().clamp(1, s._count);
              s._to = r.end.round().clamp(s._from, s._count);
            }),
          ),
          label('تكرار كل آية'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in _ListenSheetState._ayahRepeats)
                ChoiceChip(
                  label: Text('${ArabicUtils.toArabicDigits(n)}×'),
                  selected: s._ayahRepeat == n,
                    onSelected: (_) => s.update(() => s._ayahRepeat = n),
                ),
            ],
          ),
          label('تكرار المقطع كاملًا'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in _ListenSheetState._rangeRepeats)
                ChoiceChip(
                  label: Text(n == 0 ? 'بلا توقف' : '${ArabicUtils.toArabicDigits(n)}×'),
                  selected: s._rangeRepeat == n,
                    onSelected: (_) => s.update(() => s._rangeRepeat = n),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'تشغيل الآيات ${ArabicUtils.toArabicDigits(s._from)}–${ArabicUtils.toArabicDigits(s._to)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: s._playCustom,
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? primary.withValues(alpha: 0.16) : glass.onGlass.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: glass.accent.withValues(alpha: selected ? 0.6 : 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.2)),
                  child: Icon(icon, color: glass.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                      Text(subtitle, style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.expand_less_rounded : Icons.chevron_left_rounded, color: glass.onGlassMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: glass.onGlass.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
          Expanded(
            child: Text(
              ArabicUtils.toArabicDigits(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
        ],
      ),
    );
  }
}

class _SurahPicker extends StatelessWidget {
  const _SurahPicker();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: ListView.builder(
        itemCount: 114,
        itemBuilder: (context, i) {
          final info = SurahMetadata.all[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: glass.accent.withValues(alpha: 0.18),
              child: Text(ArabicUtils.toArabicDigits(info.number), style: const TextStyle(fontSize: 11)),
            ),
            title: Text('سورة ${info.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Text('${ArabicUtils.toArabicDigits(info.ayahCount)} آية',
                style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
            onTap: () => Navigator.pop(context, info.number),
          );
        },
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  final _ListenSheetState state;

  const _ReciterTile({required this.state});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final r = Reciters.byId(state._reciter);
    return Material(
      color: primary.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: glass.accent.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: state.pickReciter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: glass.accent.withValues(alpha: 0.25),
                child: Text(r.nameAr.characters.first,
                    style: TextStyle(fontWeight: FontWeight.w900, color: glass.onGlass)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('القارئ', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                    Text(r.nameAr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Text('تغيير', style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_left_rounded, color: glass.accent),
            ],
          ),
        ),
      ),
    );
  }
}

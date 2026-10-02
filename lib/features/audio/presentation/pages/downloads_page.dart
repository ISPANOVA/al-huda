import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/audio_download_service.dart';
import '../../domain/reciter.dart';
import '../cubit/downloads_cubit.dart';
import '../widgets/mini_player.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const DownloadsPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => DownloadsCubit(ctx.read<AudioDownloadService>(), ctx.read<SettingsCubit>().state.reciterId),
      child: const _DownloadsView(),
    );
  }
}

class _DownloadsView extends StatelessWidget {
  const _DownloadsView();

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${ArabicUtils.toArabicDigits((bytes / 1024).toStringAsFixed(0))} ك.ب';
    return '${ArabicUtils.toArabicDigits((bytes / (1024 * 1024)).toStringAsFixed(1))} م.ب';
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'التلاوات دون إنترنت',
      bottom: const MiniPlayer(),
      body: BlocBuilder<DownloadsCubit, DownloadsState>(
        builder: (context, state) {
          final cubit = context.read<DownloadsCubit>();
          final reciter = Reciters.byId(state.reciterId);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: 114 + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return GlassContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.record_voice_over_rounded, color: glass.accent),
                        title: Text(reciter.nameAr, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('اضغط لتغيير القارئ'),
                        trailing: const Icon(Icons.swap_horiz_rounded),
                        onTap: () async {
                          final id = await showReciterPicker(context, state.reciterId);
                          if (id != null) cubit.changeReciter(id);
                        },
                      ),
                      Text(
                        'المحمّل: ${ArabicUtils.toArabicDigits(state.downloaded.length)} / ١١٤ سورة • '
                        'المساحة المستخدمة لكل القرّاء: ${_size(state.totalBytes)}',
                        style: TextStyle(color: glass.onGlassMuted),
                      ),
                    ],
                  ),
                );
              }
              final surah = i;
              final info = SurahMetadata.surah(surah);
              final progress = state.progress[surah];
              final done = state.downloaded.contains(surah);
              final error = state.errors[surah];
              return GlassContainer(
                blur: 0,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                borderRadius: 18,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(ArabicUtils.toArabicDigits(surah),
                            style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('سورة ${info.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                error ?? '${ArabicUtils.toArabicDigits(info.ayahCount)} آية',
                                style: TextStyle(
                                    fontSize: 12, color: error != null ? Colors.red.shade300 : glass.onGlassMuted),
                              ),
                            ],
                          ),
                        ),
                        if (progress != null)
                          IconButton(
                            tooltip: 'إلغاء',
                            icon: const Icon(Icons.cancel_outlined),
                            onPressed: () => cubit.cancel(surah),
                          )
                        else if (done)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.offline_pin_rounded, color: glass.accent),
                              IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => cubit.delete(surah),
                              ),
                            ],
                          )
                        else
                          IconButton(
                            tooltip: 'تحميل',
                            icon: Icon(Icons.download_rounded, color: glass.accent),
                            onPressed: () => cubit.download(surah),
                          ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 6),
                      GlassProgressBar(value: progress, height: 6),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../domain/entities/ayah.dart';

/// Tafsir books the reader can switch between. Al-Muyassar ships with the
/// app; the others are fetched once per ayah and then kept offline.
class TafsirBook {
  final String id;
  final String name;

  /// Edition slug on the spa5k/tafsir_api dataset (null = bundled).
  final String? slug;

  const TafsirBook(this.id, this.name, this.slug);
}

const kTafsirBooks = [
  TafsirBook('muyassar', 'الميسر', null),
  TafsirBook('mukhtasar', 'المختصر', 'ar-tafsir-al-mukhtasar'),
  TafsirBook('saadi', 'السعدي', 'ar-tafsir-as-saadi'),
  TafsirBook('ibnkathir', 'ابن كثير', 'ar-tafsir-ibn-kathir'),
  TafsirBook('baghawi', 'البغوي', 'ar-tafsir-al-baghawi'),
  TafsirBook('qurtubi', 'القرطبي', 'ar-tafseer-al-qurtubi'),
  TafsirBook('tabari', 'الطبري', 'ar-tafsir-al-tabari'),
];

class TafsirService {
  TafsirService._();

  static final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static Future<String> fetch(StorageService storage, TafsirBook book, Ayah ayah) async {
    if (book.slug == null) return ayah.tafseer;
    final key = 'tafsir:${book.id}:${ayah.surah}:${ayah.numberInSurah}';
    final cached = storage.quran.get(key);
    if (cached is String && cached.isNotEmpty) return cached;
    final url = 'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/${book.slug}/${ayah.surah}/${ayah.numberInSurah}.json';
    final res = await _dio.get<dynamic>(url);
    final data = res.data;
    final text = (data is Map ? data['text'] : null)?.toString().trim() ?? '';
    if (text.isNotEmpty) await storage.quran.put(key, text);
    return text;
  }
}

/// Reads Arabic text aloud with the phone's text-to-speech voice.
class TafsirVoice {
  TafsirVoice._();

  static final FlutterTts _tts = FlutterTts();
  static final ValueNotifier<bool> speaking = ValueNotifier(false);
  static bool _ready = false;

  static Future<bool> _init() async {
    if (_ready) return true;
    try {
      final ok = await _tts.isLanguageAvailable('ar');
      if (ok != true && ok != 1) return false;
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.45);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns false when no Arabic voice is installed on the phone.
  static Future<bool> speak(String text) async {
    if (!await _init()) return false;
    await _tts.stop();
    speaking.value = true;
    await _tts.speak(text.replaceAll(RegExp(r'[{}()\[\]]'), ''));
    return true;
  }

  static Future<void> stop() async {
    speaking.value = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Tafsir box inside the ayah sheet: book chips, text and a listen button.
class TafsirPanel extends StatefulWidget {
  final Ayah ayah;

  const TafsirPanel({super.key, required this.ayah});

  @override
  State<TafsirPanel> createState() => _TafsirPanelState();
}

class _TafsirPanelState extends State<TafsirPanel> {
  static String _lastBook = 'muyassar';
  late TafsirBook _book = kTafsirBooks.firstWhere((b) => b.id == _lastBook, orElse: () => kTafsirBooks.first);
  late Future<String> _text = _load();

  Future<String> _load() => TafsirService.fetch(context.read<StorageService>(), _book, widget.ayah);

  void _select(TafsirBook b) {
    TafsirVoice.stop();
    _lastBook = b.id;
    setState(() {
      _book = b;
      _text = _load();
    });
  }

  @override
  void dispose() {
    TafsirVoice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: glass.onGlass.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: glass.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kTafsirBooks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final b = kTafsirBooks[i];
                final on = b.id == _book.id;
                return GestureDetector(
                  onTap: () => _select(b),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: on ? glass.accent : glass.accent.withValues(alpha: 0.10),
                    ),
                    child: Text(b.name,
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? Colors.black : glass.onGlass)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<String>(
            future: _text,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                );
              }
              final text = snap.data ?? '';
              if (snap.hasError || text.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    snap.hasError
                        ? 'تعذر تحميل تفسير ${_book.name}. تحقق من الاتصال بالإنترنت (يُحفظ بعد أول قراءة).'
                        : 'التفسير غير متوفر لهذه الآية.',
                    style: TextStyle(color: glass.onGlassMuted, height: 1.7),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(text, style: TextStyle(fontSize: 16, height: 1.85, color: glass.onGlass)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: TafsirVoice.speaking,
                      builder: (context, on, _) => TextButton.icon(
                        onPressed: () async {
                          if (on) {
                            await TafsirVoice.stop();
                            return;
                          }
                          final ok = await TafsirVoice.speak(text);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
                              content: Text('لا يوجد صوت عربي على هاتفك. ثبّته من الإعدادات ← تحويل النص إلى كلام.'),
                            ));
                          }
                        },
                        icon: Icon(on ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded, color: glass.accent),
                        label: Text(on ? 'إيقاف الاستماع' : 'استمع للتفسير',
                            style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

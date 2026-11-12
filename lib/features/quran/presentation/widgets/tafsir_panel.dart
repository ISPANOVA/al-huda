import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../domain/entities/ayah.dart';
import '../../../../core/i18n/text.dart';
import '../../../../core/utils/arabic_utils.dart';
import 'asbab.dart';
import 'ayah_topics.dart';
import '../../../../core/data/surah_metadata.dart';

/// Tafsir books the reader can switch between. Al-Muyassar ships with the
/// app; the others are fetched once per ayah and then kept offline.
class TafsirBook {
  final String id;
  final String name;

  /// Edition slug on the spa5k/tafsir_api dataset (null = bundled).
  final String? slug;

  /// Tafsir id on the Quran.com API: the second source, or the only one.
  final int? qc;

  const TafsirBook(this.id, this.name, this.slug, [this.qc]);
}

const kTafsirBooks = [
  TafsirBook('muyassar', 'الميسر', null),
  // Shown only for ayahs with an authenticated occasion of revelation.
  TafsirBook('asbab', 'سبب النزول', null),
  TafsirBook('topics', 'الموضوع', null),
  TafsirBook('mukhtasar', 'المختصر', 'ar-tafsir-al-mukhtasar'),
  TafsirBook('saadi', 'السعدي', 'ar-tafsir-as-saadi', 91),
  TafsirBook('ibnkathir', 'ابن كثير', 'ar-tafsir-ibn-kathir', 14),
  TafsirBook('wasit', 'الوسيط', null, 93),
  TafsirBook('baghawi', 'البغوي', 'ar-tafsir-al-baghawi', 94),
  TafsirBook('qurtubi', 'القرطبي', 'ar-tafseer-al-qurtubi', 90),
  TafsirBook('tabari', 'الطبري', 'ar-tafsir-al-tabari', 15),
];

class TafsirService {
  TafsirService._();

  static final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static Future<String> fetch(StorageService storage, TafsirBook book, Ayah ayah) async {
    if (book.id == 'asbab' || book.id == 'topics') return '';
    if (book.slug == null && book.qc == null) return ayah.tafseer;
    final key = 'tafsir:${book.id}:${ayah.surah}:${ayah.numberInSurah}';
    final cached = storage.quran.get(key);
    if (cached is String && cached.isNotEmpty) return cached;
    var text = '';
    if (book.slug != null) {
      try {
        final url = 'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/${book.slug}/${ayah.surah}/${ayah.numberInSurah}.json';
        final data = (await _dio.get<dynamic>(url)).data;
        text = (data is Map ? data['text'] : null)?.toString().trim() ?? '';
      } catch (_) {
        if (book.qc == null) rethrow;
      }
    }
    if (text.isEmpty && book.qc != null) {
      final url = 'https://api.quran.com/api/v4/tafsirs/${book.qc}/by_ayah/${ayah.surah}:${ayah.numberInSurah}';
      final data = (await _dio.get<dynamic>(url)).data;
      final raw = (data is Map && data['tafsir'] is Map ? data['tafsir']['text'] : null)?.toString() ?? '';
      text = clean(raw);
    }
    if (text.isNotEmpty) await storage.quran.put(key, text);
    return text;
  }

  /// Quran.com sends HTML: paragraphs to new lines, tags and entities out.
  static String clean(String html) => html
      .replaceAll(RegExp(r'<\s*(br|/p|/h\d|/div)[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
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

  List<TafsirBook> get _books => [for (final b in kTafsirBooks) if (b.id != 'asbab' || Asbab.loaded) b];

  @override
  void initState() {
    super.initState();
    Asbab.load().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((_) {});
    AyahTopics.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  Future<String> _load() => TafsirService.fetch(context.read<StorageService>(), _shown, widget.ayah);

  /// «سبب النزول» kept from another ayah that has none: Al-Muyassar instead.
  TafsirBook get _shown => _book;

  Widget _asbab(GlassTheme glass) {
    final a = widget.ayah;
    final list = Asbab.of(a.surah, a.numberInSurah);
    if (list.isEmpty) {
      final info = SurahMetadata.surah(a.surah);
      final near = Asbab.ayahsOf(a.surah);
      return Text(
        [
          'لم يرد لهذه الآية سبب نزول خاص في كتب أسباب النزول (${Asbab.names.join('، ')}). فأكثر القرآن نزل ابتداءً للهداية والتشريع، لا جوابًا عن حادثة أو سؤال.',
          'سورة ${info.name} ${info.isMeccan ? 'مكية' : 'مدنية'}.',
          if (near.isNotEmpty)
            'آيات من السورة لها سبب نزول: ${near.take(12).map(ArabicUtils.toArabicDigits).join('، ')}${near.length > 12 ? '…' : ''}',
        ].join('\n\n'),
        style: TextStyle(fontSize: 15, height: 1.8, color: glass.onGlassMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in list) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              [
                'من ${Asbab.names[e.source]}',
                if (e.ayahs.length > 1)
                  'الآيات ${ArabicUtils.toArabicDigits(e.ayahs.first)}–${ArabicUtils.toArabicDigits(e.ayahs.last)}',
              ].join(' • '),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: glass.accent),
            ),
          ),
          for (var i = 0; i < e.texts.length; i++) ...[
            if (i > 0) Divider(color: glass.accent.withValues(alpha: 0.2), height: 22),
            Text(e.texts[i], style: TextStyle(fontSize: 16, height: 1.85, color: glass.onGlass)),
          ],
          Divider(color: glass.accent.withValues(alpha: 0.35), height: 26),
        ],
        Text({for (final e in list) Asbab.sources[e.source]}.join('\n'), style: TextStyle(fontSize: 11.5, height: 1.6, color: glass.onGlassMuted)),
      ],
    );
  }

  Widget _topicsView(GlassTheme glass) {
    final a = widget.ayah;
    final t = AyahTopics.of(a.surah, a.numberInSurah);
    if (t == null) {
      return Text('لم تُفهرس هذه الآية ولا ما حولها في الموضوعات القرآنية بعد.',
          style: TextStyle(fontSize: 15, height: 1.8, color: glass.onGlassMuted));
    }
    // Topics under the same heading are listed together.
    final groups = <String, List<String>>{};
    for (final (name, parent) in t.topics) {
      groups.putIfAbsent(parent ?? '', () => []).add(name);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t.from != a.numberInSurah)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('من سياق الآيات: موضوع الآية ${ArabicUtils.toArabicDigits(t.from)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: glass.accent)),
          ),
        for (final g in groups.entries) ...[
          if (g.key.isNotEmpty)
            Text(g.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: glass.accent)),
          for (final n in g.value)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $n', style: TextStyle(fontSize: 16, height: 1.7, color: glass.onGlass)),
            ),
          const SizedBox(height: 10),
        ],
        Text(AyahTopics.source, style: TextStyle(fontSize: 11.5, height: 1.6, color: glass.onGlassMuted)),
      ],
    );
  }

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
              itemCount: _books.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final b = _books[i];
                final on = b.id == _shown.id;
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
          if (_shown.id == 'asbab') _asbab(glass) else if (_shown.id == 'topics') _topicsView(glass) else FutureBuilder<String>(
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
                        ? 'تعذر تحميل تفسير ${_shown.name}. تحقق من الاتصال بالإنترنت (يُحفظ بعد أول قراءة).'
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

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/juz_pages.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/theme/tones.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../../../core/i18n/text.dart';

/// One juz of a shared khatmah.
/// One juz of a shared khatmah: everyone reading it (more than one may), done
/// once any of them finishes it.
class GroupPart {
  final int part;
  final List<(String, bool)> readers; // name, finished
  final bool done;
  final bool mine; // this phone reads it
  final bool mineDone;

  const GroupPart(this.part, this.readers, this.done, this.mine, this.mineDone);

  String? get who => readers.isEmpty ? null : readers.firstWhere((r) => r.$2, orElse: () => readers.first).$1;
}

/// A khatmah shared by link (see functions/api/khatmah on the website).
class GroupKhatmah {
  final String id;
  final String name;
  final String? ownerName;
  final int round;
  final bool isOwner;
  final List<GroupPart> parts;
  final int readers; // how many people read in this khatmah
  final int? justCompleted; // this action finished khatmah number N (the next one began)
  final String? error;

  const GroupKhatmah(this.id, this.name, this.ownerName, this.round, this.isOwner, this.parts, this.readers,
      this.justCompleted, this.error);

  int get done => parts.where((p) => p.done).length;
  int get taken => parts.where((p) => p.readers.isNotEmpty).length;
  int get completed => round - 1; // khatmahs the group has finished

  factory GroupKhatmah.fromJson(Map<String, dynamic> j) => GroupKhatmah(
        j['id'] as String,
        j['name'] as String? ?? 'ختمة جماعية',
        j['ownerName'] as String?,
        (j['round'] as num?)?.toInt() ?? 1,
        j['isOwner'] == true,
        [
          for (final p in (j['parts'] as List? ?? const []))
            GroupPart(
              (p['part'] as num).toInt(),
              [
                for (final r in (p['readers'] as List? ?? const []))
                  if (r is Map) ((r['who'] ?? '').toString(), r['done'] == true),
              ],
              p['done'] == true,
              p['mine'] == true,
              p['mineDone'] == true,
            ),
        ],
        (j['readers'] as num?)?.toInt() ?? 0,
        (j['justCompleted'] as num?)?.toInt(),
        j['error'] as String?,
      );

  String get link => '${AppConstants.shareUrl}/#/group/$id';
}

class GroupError implements Exception {
  final String code;

  const GroupError(this.code);

  String get message => switch (code) {
        'disabled' => 'الختمة الجماعية لم تُفعَّل على الخادم بعد',
        'notfound' => 'لم نجد هذه الختمة، تأكد من الرابط',
        'net' => 'تعذر الاتصال، تحقق من الإنترنت',
        _ => 'حدث خطأ، حاول مرة أخرى',
      };
}

/// Talks to the website's khatmah API; keeps this phone's key, its name and
/// the khatmahs it joined.
class GroupKhatmahService {
  final Dio dio;
  final StorageService storage;

  GroupKhatmahService(this.dio, this.storage);

  static const _api = '${AppConstants.shareUrl}/api/khatmah';

  String get device {
    var d = storage.settings.get('group_device') as String?;
    if (d == null || !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(d)) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      final r = Random.secure();
      d = List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
      storage.settings.put('group_device', d);
    }
    return d;
  }

  String get name => storage.settings.get('group_name') as String? ?? '';
  set name(String v) => storage.settings.put('group_name', v);

  List<(String, String)> get joined => [
        for (final e in (storage.settings.get('group_list') as List? ?? const []))
          if (e is Map) (e['id'].toString(), e['name'].toString()),
      ];

  void remember(GroupKhatmah k) {
    final list = joined.where((e) => e.$1 != k.id).toList()..insert(0, (k.id, k.name));
    storage.settings.put('group_list', [for (final e in list.take(20)) {'id': e.$1, 'name': e.$2}]);
  }

  void forget(String id) =>
      storage.settings.put('group_list', [for (final e in joined.where((e) => e.$1 != id)) {'id': e.$1, 'name': e.$2}]);

  /// The id in a pasted link or code: «…#/group/abc123», «abc123».
  static String? idOf(String s) {
    final m = RegExp(r'([a-z0-9]{6,16})\s*$', caseSensitive: false).firstMatch(s.trim());
    return m?.group(1)?.toLowerCase();
  }

  Future<GroupKhatmah> _call(Future<Response<dynamic>> Function() send) async {
    try {
      final r = await send();
      final data = r.data;
      if (data is Map && data['parts'] is List) return GroupKhatmah.fromJson(Map<String, dynamic>.from(data));
      throw GroupError(data is Map ? (data['error'] ?? 'net').toString() : 'net');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['parts'] is List) return GroupKhatmah.fromJson(Map<String, dynamic>.from(data));
      if (data is Map && data['error'] != null) throw GroupError(data['error'].toString());
      throw GroupError(e.response?.statusCode == 503 ? 'disabled' : 'net');
    }
  }

  Options get _opts => Options(responseType: ResponseType.json, headers: {'content-type': 'application/json'});

  Future<GroupKhatmah> get(String id) =>
      _call(() => dio.get('$_api/$id', queryParameters: {'d': device}, options: _opts));

  Future<GroupKhatmah> create(String title, String who) =>
      _call(() => dio.post(_api, data: {'name': title, 'who': who, 'd': device}, options: _opts));

  Future<GroupKhatmah> act(String id, String action, [Map<String, Object?> body = const {}]) =>
      _call(() => dio.post('$_api/$id/$action', data: {...body, 'd': device}, options: _opts));
}

// ------------------------------------------------------------------ pages ---

/// الختمة الجماعية: make one, join one by its link, and the ones joined.
class GroupKhatmahListPage extends StatefulWidget {
  const GroupKhatmahListPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const GroupKhatmahListPage());

  @override
  State<GroupKhatmahListPage> createState() => _GroupKhatmahListPageState();
}

class _GroupKhatmahListPageState extends State<GroupKhatmahListPage> {
  static const _tone = Tone.teal;
  late final GroupKhatmahService _service = GroupKhatmahService(context.read<Dio>(), context.read<StorageService>());
  late final _title = TextEditingController();
  late final _who = TextEditingController(text: _service.name);
  final _link = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _who.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final who = _who.text.trim();
    if (who.isEmpty) {
      showGlassSnack(context, 'اكتب اسمك أولًا');
      return;
    }
    setState(() => _busy = true);
    try {
      _service.name = who;
      final k = await _service.create(_title.text.trim().isEmpty ? 'ختمة جماعية' : _title.text.trim(), who);
      _service.remember(k);
      if (!mounted) return;
      await Navigator.of(context).push(GroupKhatmahPage.route(k.id, invite: true));
      if (mounted) setState(() {});
    } on GroupError catch (e) {
      if (mounted) showGlassSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final id = GroupKhatmahService.idOf(_link.text);
    if (id == null) {
      showGlassSnack(context, 'الرابط غير صحيح');
      return;
    }
    await Navigator.of(context).push(GroupKhatmahPage.route(id));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final joined = _service.joined;
    InputDecoration field(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: glass.onGlass.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
    return GlassScaffold(
      title: 'الختمة الجماعية',
      subtitle: 'اختموا القرآن معًا، كل واحد بجزء',
      icon: Icons.groups_rounded,
      tone: _tone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ToneCard(
            tone: _tone,
            solid: true,
            ornament: true,
            padding: const EdgeInsets.all(18),
            child: const Text(
              'أنشئ ختمة وأرسل رابطها لأهلك وأصحابك: يختار كل واحد جزءًا، ويعلّمه عند إتمامه، ويرى الجميع تقدّم الختمة.',
              style: TextStyle(color: Colors.white, height: 1.8, fontWeight: FontWeight.w700),
            ),
          ),
          const GlassSectionTitle('ختمة جديدة', tone: _tone),
          NoorCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _title, maxLength: 60, decoration: field('اسم الختمة، مثل: ختمة العائلة')),
                TextField(controller: _who, maxLength: 30, decoration: field('اسمك')),
                const SizedBox(height: 4),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _tone.deep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy ? null : _create,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.flag_rounded, color: Colors.white),
                  label: const Text('إنشاء الختمة', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
          const GlassSectionTitle('الانضمام برابط', tone: _tone),
          NoorCard(
            child: Row(
              children: [
                Expanded(child: TextField(controller: _link, decoration: field('الصق رابط الختمة أو رمزها'))),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: tr('لصق'),
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
                    if (t != null) _link.text = t;
                  },
                ),
                const SizedBox(width: 6),
                FilledButton(onPressed: _join, child: const Text('انضمام')),
              ],
            ),
          ),
          if (joined.isNotEmpty) ...[
            const GlassSectionTitle('ختماتي', tone: _tone),
            NoorCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final g in joined)
                    ListTile(
                      leading: const ToneIcon(Icons.flag_rounded, tone: _tone, size: 40),
                      title: Text(g.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: const Icon(kGoChevron),
                      onTap: () async {
                        await Navigator.of(context).push(GroupKhatmahPage.route(g.$1));
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One shared khatmah: its 30 parts, who took each and who finished.
class GroupKhatmahPage extends StatefulWidget {
  final String id;
  final bool invite; // just made: offer to send the link at once

  const GroupKhatmahPage({super.key, required this.id, this.invite = false});

  static Route<void> route(String id, {bool invite = false}) =>
      MaterialPageRoute(builder: (_) => GroupKhatmahPage(id: id, invite: invite));

  @override
  State<GroupKhatmahPage> createState() => _GroupKhatmahPageState();
}

class _GroupKhatmahPageState extends State<GroupKhatmahPage> {
  static const _tone = Tone.teal;
  late final GroupKhatmahService _service = GroupKhatmahService(context.read<Dio>(), context.read<StorageService>());
  GroupKhatmah? _k;
  GroupError? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    try {
      final k = await _service.get(widget.id);
      _service.remember(k);
      if (!mounted) return;
      setState(() {
        _k = k;
        _error = null;
      });
      if (first && widget.invite) _invite();
    } on GroupError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(String action, [Map<String, Object?> body = const {}]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final k = await _service.act(widget.id, action, body);
      if (!mounted) return;
      setState(() => _k = k);
      if (k.justCompleted != null) {
        showGlassSnack(context,
            'تمّت الختمة رقم ${ArabicUtils.toArabicDigits(k.justCompleted!)}، تقبّل الله منا ومنكم. بدأت الختمة التالية',
            icon: Icons.celebration_rounded);
      }
    } on GroupError catch (e) {
      if (mounted) showGlassSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invite() {
    final k = _k;
    if (k == null) return;
    SharePlus.instance.share(ShareParams(text: 'انضم إلى «${k.name}» واختر جزءًا تقرؤه، نختم القرآن معًا 🤍\n${k.link}'));
  }

  Future<String?> _askName() async {
    final c = TextEditingController(text: _service.name);
    final name = await showGlassSheet<String>(context, builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اسمك', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text('يظهر على الجزء الذي تختاره', textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextField(controller: c, autofocus: true, maxLength: 30, onSubmitted: (v) => Navigator.of(ctx).pop(v.trim())),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('تم')),
          ],
        ),
      );
    });
    c.dispose();
    if (name == null || name.isEmpty) return null;
    _service.name = name;
    return name;
  }

  /// A juz: who reads it, and read it / I'll read it / I finished it.
  Future<void> _tapPart(GroupPart p) async {
    final choice = await showGlassSheet<String>(context, builder: (ctx) {
      final glass = GlassTheme.of(ctx);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الجزء ${ArabicUtils.toArabicDigits(p.part)}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (p.readers.isEmpty)
            Text('لم يختره أحد بعد.', textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted))
          else
            for (final r in p.readers)
              ListTile(
                dense: true,
                leading: Icon(r.$2 ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                    color: r.$2 ? Tone.emerald.mid : glass.onGlassMuted),
                title: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(r.$2 ? 'أتمّه' : 'يقرؤه', style: TextStyle(color: glass.onGlassMuted)),
              ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('اقرأ الجزء في المصحف'),
            onTap: () => Navigator.of(ctx).pop('read'),
          ),
          if (p.mine) ...[
            ListTile(
              leading: Icon(p.mineDone ? Icons.undo_rounded : Icons.check_circle_rounded),
              title: Text(p.mineDone ? 'لم أُتمّه بعد' : 'أتممت قراءته'),
              onTap: () => Navigator.of(ctx).pop('done'),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('لن أقرأه'),
              onTap: () => Navigator.of(ctx).pop('release'),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: Text(p.readers.isEmpty ? 'سأقرأ هذا الجزء' : 'سأقرؤه أنا أيضًا'),
              onTap: () => Navigator.of(ctx).pop('claim'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_rounded),
              title: const Text('قرأته بالفعل'),
              onTap: () => Navigator.of(ctx).pop('finished'),
            ),
          ],
        ],
      );
    });
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'read':
        MushafReaderPage.open(context, page: kJuzStartPages[p.part - 1]);
        return;
      case 'done':
        await _act('done', {'part': p.part, 'done': !p.mineDone});
        return;
      case 'release':
        await _act('release', {'part': p.part});
        return;
    }
    final who = _service.name.isNotEmpty ? _service.name : await _askName();
    if (who == null || !mounted) return;
    await _act(choice == 'claim' ? 'claim' : 'done', {'part': p.part, 'who': who, 'done': true});
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة الختمة'),
        content: const Text('تُفرَّغ أجزاء هذه الختمة ويبدأ الجميع من جديد بنفس الرابط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ من جديد')),
        ],
      ),
    );
    if (ok == true) await _act('restart');
  }

  @override
  Widget build(BuildContext context) {
    final k = _k;
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      title: k?.name ?? 'الختمة الجماعية',
      subtitle: k == null ? null : 'يقرأ معكم ${ArabicUtils.toArabicDigits(k.readers)}',
      icon: Icons.groups_rounded,
      tone: _tone,
      actions: [
        if (k != null) IconButton(tooltip: tr('ادعُ غيرك'), icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: _invite),
      ],
      body: _error != null
          ? MessageView(
              icon: Icons.cloud_off_rounded,
              title: _error!.message,
              actionLabel: 'إعادة المحاولة',
              onAction: () {
                setState(() => _error = null);
                _load();
              },
            )
          : k == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      ToneCard(
                        tone: _tone,
                        solid: true,
                        ornament: true,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'أُتمّ ${ArabicUtils.toArabicDigits(k.done)} من ٣٠ جزءًا',
                                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Text('${ArabicUtils.toArabicDigits((k.done * 100 / 30).round())}٪',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 22, fontFamily: AppFonts.display, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: k.done / 30,
                                minHeight: 8,
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (k.ownerName != null && k.ownerName!.isNotEmpty) 'أنشأها ${k.ownerName}',
                                if (k.completed > 0)
                                  'أتممتم ${ArabicUtils.toArabicDigits(k.completed)} ${k.completed == 1 ? 'ختمة' : 'ختمات'} معًا',
                                'اسحب للأسفل للتحديث',
                              ].join(' • '),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _tone.deep,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _invite,
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        label: const Text('ادعُ غيرك إلى الختمة', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      const GlassSectionTitle('الأجزاء', tone: _tone),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'اختر أي جزء تقرؤه، حتى لو كان غيرك يقرؤه. يُحتسب الجزء عند أول من يتمّه، وعند تمام الثلاثين تبدأ ختمة جديدة بنفس الرابط.',
                          style: TextStyle(fontSize: 12, height: 1.6, color: glass.onGlassMuted),
                        ),
                      ),
                      LayoutBuilder(builder: (context, box) {
                        final cols = box.maxWidth >= 560 ? 6 : 5;
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.82,
                          children: [
                            for (final p in k.parts)
                              Material(
                                color: p.done
                                    ? Tone.emerald.deep
                                    : p.who != null
                                        ? glass.accent.withValues(alpha: 0.14)
                                        : glass.onGlass.withValues(alpha: dark ? 0.05 : 0.04),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: p.mine
                                        ? glass.accent
                                        : p.who != null
                                            ? glass.accent.withValues(alpha: 0.35)
                                            : glass.onGlass.withValues(alpha: 0.12),
                                    width: p.mine ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _busy ? null : () => _tapPart(p),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(ArabicUtils.toArabicDigits(p.part),
                                            style: TextStyle(
                                                fontFamily: AppFonts.display,
                                                fontSize: 20,
                                                color: p.done ? Colors.white : glass.accent)),
                                        Text(
                                          p.done
                                              ? 'تمّ'
                                              : p.readers.isEmpty
                                                  ? 'متاح'
                                                  : p.readers.length == 1
                                                      ? p.readers.first.$1
                                                      : '${ArabicUtils.toArabicDigits(p.readers.length)} يقرؤونه',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              color: p.done ? Colors.white : glass.onGlassMuted,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                      if (k.isOwner) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _restart,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('إعادة هذه الختمة من البداية'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _service.forget(widget.id);
                          Navigator.of(context).pop();
                        },
                        child: const Text('إزالة من ختماتي'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

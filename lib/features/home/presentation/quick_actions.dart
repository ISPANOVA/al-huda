import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../audio/presentation/pages/downloads_page.dart';
import '../../audio/presentation/pages/memorization_page.dart';
import '../../audio/presentation/pages/player_page.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../qibla/presentation/pages/qibla_page.dart';
import '../../quran/presentation/pages/quran_search_page.dart';
import '../../settings/presentation/pages/settings_page.dart';
import '../../stats/presentation/stats_page.dart';
import '../../tasbeeh/presentation/pages/tasbeeh_page.dart';
import '../../virtues/virtues_pages.dart';
import '../../calendar/calendar_page.dart';
import '../../duas/duas_page.dart';
import '../../hifz/hifz_review_page.dart';

/// One shortcut the user can pin to the home screen.
class QuickActionDef {
  final String id;
  final IconData icon;
  final String label;

  /// Bottom-tab index to switch to, or null when [route] is used.
  final int? tab;
  final Route<void> Function()? route;

  const QuickActionDef(this.id, this.icon, this.label, {this.tab, this.route});
}

final List<QuickActionDef> kQuickActions = [
  const QuickActionDef('mushaf', Icons.menu_book_rounded, 'المصحف', tab: 1),
  const QuickActionDef('athkar', Icons.favorite_rounded, 'الأذكار', tab: 4),
  const QuickActionDef('media', Icons.headphones_rounded, 'الوسائط', tab: 2),
  const QuickActionDef('prayer', Icons.access_time_filled_rounded, 'الصلاة', tab: 3),
  const QuickActionDef('tasbeeh', Icons.blur_circular_rounded, 'المسبحة', route: TasbeehPage.route),
  const QuickActionDef('khatmah', Icons.flag_rounded, 'الختمة', route: KhatmahPage.route),
  const QuickActionDef('hifz', Icons.repeat_on_rounded, 'الحفظ', route: MemorizationPage.route),
  const QuickActionDef('qibla', Icons.explore_rounded, 'القبلة', route: QiblaPage.route),
  const QuickActionDef('virtues', Icons.auto_awesome_rounded, 'الفضائل', route: VirtuesPage.route),
  const QuickActionDef('ruqyah', Icons.healing_rounded, 'الرقية', route: RuqyahPage.route),
  const QuickActionDef('search', Icons.manage_search_rounded, 'بحث في القرآن', route: QuranSearchPage.route),
  const QuickActionDef('duas', Icons.back_hand_rounded, 'الأدعية', route: DuasPage.route),
  const QuickActionDef('calendar', Icons.calendar_month_rounded, 'التقويم', route: CalendarPage.route),
  const QuickActionDef('review', Icons.psychology_rounded, 'مراجعة الحفظ', route: HifzReviewPage.route),
  const QuickActionDef('player', Icons.headphones_rounded, 'المشغل', route: PlayerPage.route),
  const QuickActionDef('downloads', Icons.download_for_offline_rounded, 'التحميلات', route: DownloadsPage.route),
  const QuickActionDef('stats', Icons.insights_rounded, 'إحصائياتي', route: StatsPage.route),
  const QuickActionDef('settings', Icons.settings_rounded, 'الإعدادات', route: SettingsPage.route),
];

const _defaultIds = ['mushaf', 'athkar', 'tasbeeh', 'khatmah', 'hifz', 'qibla'];
const _storageKey = 'quick_actions';

/// "وصول سريع" grid; the user picks, removes and reorders its shortcuts.
class QuickActionsSection extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const QuickActionsSection({super.key, required this.onNavigate});

  @override
  State<QuickActionsSection> createState() => _QuickActionsSectionState();
}

class _QuickActionsSectionState extends State<QuickActionsSection> {
  late List<String> _ids = _load();

  List<String> _load() {
    final raw = context.read<StorageService>().settings.get(_storageKey);
    if (raw is List) {
      final known = kQuickActions.map((a) => a.id).toSet();
      return raw.map((e) => e.toString()).where(known.contains).toList();
    }
    return List.of(_defaultIds);
  }

  Future<void> _save(List<String> ids) async {
    setState(() => _ids = ids);
    await context.read<StorageService>().settings.put(_storageKey, ids);
  }

  void _run(QuickActionDef a) {
    if (a.tab != null) {
      widget.onNavigate(a.tab!);
    } else if (a.route != null) {
      Navigator.of(context).push(a.route!());
    }
  }

  Future<void> _edit() async {
    final result = await showGlassSheet<List<String>>(context, builder: (ctx) => _EditSheet(selected: _ids));
    if (result != null) await _save(result);
  }

  @override
  Widget build(BuildContext context) {
    final actions = [for (final id in _ids) kQuickActions.firstWhere((a) => a.id == id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, right: 0),
          child: NoorSection('وصول سريع', action: 'تخصيص', onAction: _edit),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          childAspectRatio: 0.92,
          children: [
            for (final a in actions) _QuickTile(def: a, onTap: () => _run(a), onLongPress: _edit),
            _AddTile(onTap: _edit),
          ],
        ),
      ],
    );
  }
}

class _SoftIcon extends StatelessWidget {
  final IconData icon;
  final bool dashed;

  const _SoftIcon({required this.icon, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        color: dashed ? Colors.transparent : null,
        gradient: dashed
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [glass.accent.withValues(alpha: 0.22), glass.accent.withValues(alpha: 0.08)],
              ),
        border: Border.all(color: glass.accent.withValues(alpha: dashed ? 0.35 : 0.22)),
      ),
      child: Icon(icon, color: glass.accent, size: 25),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final QuickActionDef def;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickTile({required this.def, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SoftIcon(icon: def.icon),
          const SizedBox(height: 7),
          Text(def.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: glass.onGlass)),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SoftIcon(icon: Icons.add_rounded, dashed: true),
          const SizedBox(height: 7),
          Text('إضافة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: glass.onGlassMuted)),
        ],
      ),
    );
  }
}

/// Pick shortcuts (checkbox) and reorder the chosen ones (drag handle).
class _EditSheet extends StatefulWidget {
  final List<String> selected;

  const _EditSheet({required this.selected});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final List<String> _order = [
    ...widget.selected,
    for (final a in kQuickActions)
      if (!widget.selected.contains(a.id)) a.id,
  ];
  late final Set<String> _on = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Text('تخصيص الوصول السريع',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('فعّل ما تريد، واسحب ☰ لتغيير الترتيب',
              style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _order.length,
              onReorder: (from, to) => setState(() {
                if (to > from) to--;
                _order.insert(to, _order.removeAt(from));
              }),
              itemBuilder: (context, i) {
                final a = kQuickActions.firstWhere((e) => e.id == _order[i]);
                final on = _on.contains(a.id);
                return ListTile(
                  key: ValueKey(a.id),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Checkbox(
                    value: on,
                    onChanged: (v) => setState(() => v == true ? _on.add(a.id) : _on.remove(a.id)),
                  ),
                  title: Row(
                    children: [
                      Icon(a.icon, color: on ? glass.accent : glass.onGlassMuted, size: 22),
                      const SizedBox(width: 10),
                      Text(a.label, style: TextStyle(fontWeight: FontWeight.w700, color: on ? null : glass.onGlassMuted)),
                    ],
                  ),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_handle_rounded, color: glass.onGlassMuted),
                  ),
                  onTap: () => setState(() => on ? _on.remove(a.id) : _on.add(a.id)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, List<String>.of(_defaultIds)),
                child: const Text('الافتراضي'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, [for (final id in _order) if (_on.contains(id)) id]),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

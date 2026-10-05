import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/repositories/quran_repository.dart';
import '../cubit/quran_search_cubit.dart';
import '../mushaf/mushaf_reader_page.dart';

class QuranSearchPage extends StatelessWidget {
  const QuranSearchPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const QuranSearchPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => QuranSearchCubit(ctx.read<QuranRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Open the keyboard only after the page transition finishes, so the two
    // animations don't fight over layout (that was the stutter on open).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anim = ModalRoute.of(context)?.animation;
      if (anim == null || anim.isCompleted) {
        _focus.requestFocus();
      } else {
        void onStatus(AnimationStatus s) {
          if (s.isCompleted) {
            anim.removeStatusListener(onStatus);
            if (mounted) _focus.requestFocus();
          }
        }
        anim.addStatusListener(onStatus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<QuranSearchCubit>();
    final fieldRadius = BorderRadius.circular(22);
    return GlassScaffold(
      title: 'البحث في القرآن',
      subtitle: 'في المصحف كاملًا ودون إنترنت',
      icon: Icons.manage_search_rounded,
      tone: Tone.emerald,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              focusNode: _focus,
              onChanged: cubit.onQueryChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: glass.onGlass),
              decoration: InputDecoration(
                hintText: 'اكتب كلمة أو جزءًا من آية (دون تشكيل)',
                hintStyle: TextStyle(fontSize: 14, color: glass.onGlassMuted),
                filled: true,
                fillColor: noorSurface(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                prefixIcon: const Padding(
                  padding: EdgeInsetsDirectional.only(start: 10, end: 8),
                  child: ToneIcon(Icons.search_rounded, tone: Tone.emerald, size: 36),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 54, minHeight: 36),
                border: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: Tone.emerald.mid.withValues(alpha: dark ? 0.35 : 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: Tone.emerald.mid.withValues(alpha: dark ? 0.35 : 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: Tone.emerald.mid, width: 1.8),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<QuranSearchCubit, QuranSearchState>(
              builder: (context, state) {
                if (state.query.trim().length < 2) {
                  return const MessageView(
                    icon: Icons.manage_search_rounded,
                    title: 'ابحث في كتاب الله',
                    subtitle: 'البحث فوري ويعمل دون إنترنت في المصحف كاملًا.',
                  );
                }
                if (state.searching && state.results.isEmpty) return const LoadingView();
                if (state.results.isEmpty) {
                  return const MessageView(icon: Icons.search_off_rounded, title: 'لا توجد نتائج مطابقة');
                }
                return ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  addAutomaticKeepAlives: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: state.results.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Tone.emerald.mid.withValues(alpha: dark ? 0.16 : 0.12),
                              border: Border.all(color: Tone.emerald.mid.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.list_alt_rounded, size: 16, color: Tone.emerald.ink(dark)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    state.results.length >= 300
                                        ? 'أكثر من ٣٠٠ نتيجة، حدد البحث أكثر'
                                        : '${ArabicUtils.toArabicDigits(state.results.length)} نتيجة',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5, fontWeight: FontWeight.w800, color: Tone.emerald.ink(dark)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final r = state.results[i - 1];
                    return RepaintBoundary(
                      child: _ResultTile(
                        surah: 'سورة ${r.surahName}',
                        ayah: ArabicUtils.toArabicDigits(r.ayah.numberInSurah),
                        page: 'صفحة ${ArabicUtils.toArabicDigits(r.ayah.page)}',
                        text: ArabicUtils.snippet(r.ayah.text, state.query),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          MushafReaderPage.open(context, surah: r.ayah.surah, ayah: r.ayah.numberInSurah);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One match: the ayah number in a little star, the surah and page, and the
/// matching words in the Quran face.
class _ResultTile extends StatelessWidget {
  final String surah;
  final String ayah;
  final String page;
  final String text;
  final VoidCallback onTap;

  const _ResultTile({
    required this.surah,
    required this.ayah,
    required this.page,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.emerald;
    final radius = BorderRadius.circular(20);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: noorSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tone.mid.withValues(alpha: dark ? 0.26 : 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(gradient: tone.wash(dark)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 34,
                        child: CustomPaint(
                          painter: KhatamPainter(tone.ink(dark).withValues(alpha: 0.8), stroke: 1.2),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: FittedBox(
                                child: Text(ayah,
                                    style: TextStyle(fontWeight: FontWeight.w900, color: tone.ink(dark))),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(surah,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: tone.ink(dark))),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: glass.onGlass.withValues(alpha: 0.06),
                        ),
                        child: Text(page,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: glass.onGlassMuted)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_left_rounded, size: 20, color: glass.onGlassMuted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: QuranFont.amiriQuran.style(fontSize: 20, height: 1.9, color: glass.onGlass),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

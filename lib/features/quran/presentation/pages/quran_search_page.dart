import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/gradient_background.dart';
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
    final cubit = context.read<QuranSearchCubit>();
    return GlassScaffold(
      title: 'البحث في القرآن',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              focusNode: _focus,
              onChanged: cubit.onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'اكتب كلمة أو جزءًا من آية (دون تشكيل)',
                prefixIcon: Icon(Icons.search_rounded),
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: state.results.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          state.results.length >= 300
                              ? 'أكثر من ٣٠٠ نتيجة، حدد البحث أكثر'
                              : '${ArabicUtils.toArabicDigits(state.results.length)} نتيجة',
                          style: TextStyle(color: glass.onGlassMuted),
                        ),
                      );
                    }
                    final r = state.results[i - 1];
                    return RepaintBoundary(
                      child: _ResultTile(
                        reference:
                            'سورة ${r.surahName} • الآية ${ArabicUtils.toArabicDigits(r.ayah.numberInSurah)} • صفحة ${ArabicUtils.toArabicDigits(r.ayah.page)}',
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

class _ResultTile extends StatelessWidget {
  final String reference;
  final String text;
  final VoidCallback onTap;

  const _ResultTile({required this.reference, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Material(
        color: glass.onGlass.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: glass.accent.withValues(alpha: 0.22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(reference, style: TextStyle(fontWeight: FontWeight.w800, color: glass.accent, fontSize: 13)),
                const SizedBox(height: 4),
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
    );
  }
}

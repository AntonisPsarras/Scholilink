import 'dart:async' show StreamSubscription, unawaited;
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../navigation/data/navigation_provider.dart';
import 'floating_island_nav.dart';
import 'dashboard_screen.dart';
import 'homework_feed_screen.dart';
import 'classes_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../classroom/presentation/classroom_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import 'exam_tracker_screen.dart';

import '../../auth/data/auth_repository.dart';
import '../../../core/spark_sync.dart';
import '../../../shared/performance_config.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/responsive_layout.dart';
import 'desktop_sidebar_nav.dart';
import 'desktop_social_sidebar.dart';
import '../../ai_tutor/presentation/study_buddy_screen.dart';
import '../../ai_notes/presentation/smart_notes_screen.dart';
import '../../messaging/data/direct_message_service.dart';
import '../../messaging/data/dm_navigation_intent.dart';
import '../../messaging/presentation/direct_chat_screen.dart';
import '../../classroom/data/classroom_providers.dart';
import '../../classroom/data/friendship_service.dart';
import '../../../shared/push_notification_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
/// Main shell: mobile [PageView] + [FloatingIslandNav], desktop sidebar + stack.
class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 5;
  // Only the 2 most-recently-active tabs are retained in the widget tree.
  // Tabs evicted from this list are allowed to dispose when scrolled away,
  // which frees memory and reduces background provider activity.
  static const int _maxKeepAliveTabs = 2;

  late PageController _pageController;

  /// Tabs instantiated only after first visit; kept alive once built.
  final Set<int> _visitedTabIndices = {};

  /// Ordered list of recently active tab indices (newest at end).
  /// Max [_maxKeepAliveTabs] entries.
  final List<int> _recentlyActiveTabIndices = [];

  // Use ValueNotifier instead of setState for scroll delta —
  // this isolates the jelly transform from the rest of the scaffold
  final ValueNotifier<double> _scrollDeltaNotifier = ValueNotifier(0.0);

  late AnimationController _jellyController;
  late Animation<double> _jellyAnimation;
  StreamSubscription<DmNavigationIntent>? _dmNavSub;

  static const int _messagesTabIndex = 3;

  @override
  void initState() {
    super.initState();
    _dmNavSub = PushNotificationService.instance.dmNavigationStream.listen(
      _openDirectChatFromNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          if (ref.read(authStateProvider).valueOrNull != null) {
            await syncSparkStatusFromServer(ref);
          }
        }),
      );
    });
    final initialIndex = ref.read(navigationProvider);
    _recordActiveTab(initialIndex);
    _ensureTabVisited(initialIndex, includeAdjacent: false, silent: true);
    _pageController = PageController(initialPage: initialIndex);

    _jellyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _jellyAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _jellyController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _dmNavSub?.cancel();
    _pageController.dispose();
    _jellyController.dispose();
    _scrollDeltaNotifier.dispose();
    super.dispose();
  }

  Future<void> _openDirectChatFromNotification(DmNavigationIntent intent) async {
    if (!mounted) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final chatDoc = await FirebaseFirestore.instance
        .collection('direct_chats')
        .doc(intent.chatId)
        .get();
    if (!mounted) return;
    if (!chatDoc.exists) return;

    final participants = List<String>.from(
      chatDoc.data()?['participants'] ?? const [],
    );
    if (!participants.contains(user.uid) ||
        !participants.contains(intent.friendId) ||
        intent.friendId == user.uid) {
      return;
    }

    ref.read(navigationProvider.notifier).state = _messagesTabIndex;
    _onNavigationChanged(_messagesTabIndex);

    final friend =
        await ref.read(friendshipServiceProvider).getUserByUid(intent.friendId);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          friendId: intent.friendId,
          currentUserId: user.uid,
          friendName: friend?.fullName.isNotEmpty == true
              ? friend!.fullName
              : (user.preferredLanguage == 'el' ? 'Φίλος' : 'Friend'),
          friendAvatar: friend?.profilePictureUrl,
          lang: user.preferredLanguage,
        ),
      ),
    );
  }

  void _onNavigationChanged(int index) {
    if (_pageController.hasClients) {
      final currentIndex = _pageController.page?.round() ?? 0;
      if (currentIndex != index) {
        if ((currentIndex - index).abs() > 1) {
          _pageController.jumpToPage(
            index > currentIndex ? index - 1 : index + 1,
          );
        }
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
        );
      }
    }
  }

  /// Marks [index] as built. Optionally prebuilds neighbors so [PageView] swipes
  /// do not flash an empty slot (still lazy for distant tabs).
  /// Use [silent] during [initState] (no [setState] allowed there).
  void _ensureTabVisited(
    int index, {
    bool includeAdjacent = false,
    bool silent = false,
  }) {
    if (index < 0 || index >= _tabCount) return;
    var changed = false;
    void mark(int i) {
      if (i >= 0 && i < _tabCount && !_visitedTabIndices.contains(i)) {
        _visitedTabIndices.add(i);
        changed = true;
      }
    }

    mark(index);
    if (includeAdjacent) {
      mark(index - 1);
      mark(index + 1);
    }
    if (changed && !silent) setState(() {});
  }

  /// Records [index] as the most recently active tab and evicts the oldest
  /// entry when the keep-alive pool exceeds [_maxKeepAliveTabs].
  void _recordActiveTab(int index) {
    _recentlyActiveTabIndices.remove(index);
    _recentlyActiveTabIndices.add(index);
    if (_recentlyActiveTabIndices.length > _maxKeepAliveTabs) {
      _recentlyActiveTabIndices.removeAt(0);
    }
  }

  Widget _rootTabForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const HomeworkFeedScreen();
      case 2:
        return const ClassesScreen();
      case 3:
        return const ClassroomScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  /// FAB inner content — blurred when [PerformanceConfig.useBlur] is true,
  /// flat semi-transparent otherwise (avoids an always-on [BackdropFilter] on
  /// mid/low-tier devices where every backdrop pass is expensive).
  Widget _buildFabContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.35);
    final border = Border.all(
      color: Colors.white.withValues(alpha: 0.15),
      width: 1,
    );
    final icon = Center(
      child: Icon(
        Icons.add_rounded,
        color: isDark ? Colors.white : context.brand.darkText,
        size: 32,
      ),
    );
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: bgColor,
      border: border,
    );

    if (PerformanceConfig.useBlur) {
      final sigma = PerformanceConfig.blurSigma.clamp(0.0, 10.0);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(width: 56, height: 56, decoration: decoration, child: icon),
      );
    }
    return Container(width: 56, height: 56, decoration: decoration, child: icon);
  }

  /// Lazy slot for [PageView.builder] before a tab is ever opened.
  Widget _unbuiltTabPlaceholder() {
    return const ColoredBox(
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }

  /// Horizontal PageView skew: [elasticSnap] uses [AnimationController] snap-back; when false,
  /// skew follows drag only (reduced motion or [PerformanceConfig.useJellyScroll] off).
  bool _onHorizontalPageScroll(
    ScrollNotification scrollInfo, {
    required bool elasticSnap,
  }) {
    if (scrollInfo.metrics.axis != Axis.horizontal) return false;

    if (scrollInfo is ScrollUpdateNotification) {
      _scrollDeltaNotifier.value = scrollInfo.scrollDelta ?? 0.0;
    } else if (scrollInfo is ScrollEndNotification) {
      if (elasticSnap) {
        final currentDelta = _scrollDeltaNotifier.value;
        _jellyAnimation = Tween<double>(begin: currentDelta, end: 0.0).animate(
          CurvedAnimation(parent: _jellyController, curve: Curves.elasticOut),
        );
        _jellyController.forward(from: 0.0);
      }
      _scrollDeltaNotifier.value = 0.0;
    }
    return false;
  }

  Widget _wrappedTabContent({
    required int index,
    required int selectedIndex,
    required Widget child,
  }) {
    return TickerMode(
      enabled: selectedIndex == index,
      child: _KeepAliveTabWrapper(
        keepAlive: _recentlyActiveTabIndices.contains(index),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(pendingFriendRequestUidsProvider, (
      previous,
      next,
    ) {
      if (previous != null && next.length > previous.length) {
        final lang =
            ref.read(authStateProvider).value?.preferredLanguage ?? 'el';
        CustomSnackBar.show(
          context: context,
          message: S(lang).newRequest,
          type: SnackBarType.info,
        );
      }
    });

    ref.listen<int>(navigationProvider, (previous, next) {
      // Clear any open center overlay when the user switches tabs.
      ref.read(centerOverlayProvider.notifier).state = null;
      _ensureTabVisited(next, includeAdjacent: true);
      _onNavigationChanged(next);
    });

    final selectedIndex = ref.watch(navigationProvider);

    return ResponsiveLayout(
      mobileScaffold: _buildMobileScaffold(context, selectedIndex),
      tabletScaffold: _buildTabletScaffold(context, selectedIndex),
      desktopScaffold: _buildDesktopScaffold(context, selectedIndex),
    );
  }

  Widget _buildMobileScaffold(BuildContext context, int selectedIndex) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final useElasticJelly = PerformanceConfig.useJellyScroll && !reduceMotion;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) => _onHorizontalPageScroll(
              scrollInfo,
              elasticSnap: useElasticJelly,
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollDeltaNotifier,
              builder: (context, scrollDelta, child) {
                if (useElasticJelly) {
                  return AnimatedBuilder(
                    animation: _jellyController,
                    builder: (context, child) {
                      final stretch = _jellyController.isAnimating
                          ? _jellyAnimation.value
                          : scrollDelta;

                      // Skew horizontally based on swipe speed to create jelly stretch
                      final skewAmount = (stretch / 800).clamp(-0.04, 0.04);

                      return Transform(
                        transform: Matrix4.skewX(-skewAmount),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    child: child,
                  );
                }
                final skewAmount = (scrollDelta / 800).clamp(-0.04, 0.04);
                return Transform(
                  transform: Matrix4.skewX(-skewAmount),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tabCount,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                onPageChanged: (index) {
                  _recordActiveTab(index);
                  _ensureTabVisited(index, includeAdjacent: true);
                  ref.read(navigationProvider.notifier).state = index;
                },
                itemBuilder: (context, index) {
                  if (!_visitedTabIndices.contains(index)) {
                    return _unbuiltTabPlaceholder();
                  }
                  return _wrappedTabContent(
                    index: index,
                    selectedIndex: selectedIndex,
                    child: _rootTabForIndex(index),
                  );
                },
              ),
            ),
          ),
          RepaintBoundary(
            child: _UnreadAwareFloatingIslandNav(selectedIndex: selectedIndex),
          ),
          // Central Quick Add FAB
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 80,
              ), // Increased from 74 — better spacing above nav
                child: LiquidTouch(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    barrierColor:
                        Theme.of(context).brightness == Brightness.light
                        ? Colors.black.withValues(alpha: 0.48)
                        : null,
                    builder: (context) => _buildQuickAddSheet(context),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _buildFabContent(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopScaffold(BuildContext context, int selectedIndex) {
    return _buildAdaptiveDesktopShell(
      context: context,
      selectedIndex: selectedIndex,
      includeRightSidebar: true,
    );
  }

  Widget _buildTabletScaffold(BuildContext context, int selectedIndex) {
    return _buildAdaptiveDesktopShell(
      context: context,
      selectedIndex: selectedIndex,
      includeRightSidebar: false,
    );
  }

  Widget _buildAdaptiveDesktopShell({
    required BuildContext context,
    required int selectedIndex,
    required bool includeRightSidebar,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final leftWidth = (width * 0.18).clamp(220.0, 280.0);
          final rightWidth = includeRightSidebar
              ? (width * 0.24).clamp(320.0, 420.0)
              : 0.0;
          final availableCenter = width - leftWidth - rightWidth;
          final centerMaxWidth = includeRightSidebar
              ? availableCenter.clamp(760.0, 1200.0)
              : availableCenter.clamp(820.0, 1400.0);

          return Row(
            children: [
              SizedBox(
                width: leftWidth,
                child: DesktopSidebarNav(
                  selectedIndex: selectedIndex,
                  onItemTapped: (index) {
                    ref.read(navigationProvider.notifier).state = index;
                    // For desktop, no page controller animations are needed,
                    // but we jump the page controller to stay in sync if resized to mobile
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(index);
                    }
                  },
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: centerMaxWidth),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        for (final i in _visitedTabIndices)
                          Offstage(
                            offstage: selectedIndex != i,
                            child: TickerMode(
                              enabled: selectedIndex == i,
                              child: IgnorePointer(
                                ignoring: selectedIndex != i,
                                child: _KeepAliveTabWrapper(
                                  keepAlive: _recentlyActiveTabIndices.contains(i),
                                  child: _rootTabForIndex(i),
                                ),
                              ),
                            ),
                          ),
                        // Desktop center-area overlay (e.g. schedule editor,
                        // edit profile, classroom chat). Rendered on top of the
                        // tab content inside the center column so sidebars stay
                        // visible and interactive.
                        Consumer(
                          builder: (ctx, ref, _) {
                            final overlay = ref.watch(centerOverlayProvider);
                            if (overlay == null) return const SizedBox.shrink();
                            return _CenterOverlayHost(overlay: overlay);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (includeRightSidebar)
                SizedBox(
                  width: rightWidth,
                  child: const DesktopSocialSidebar(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickAddSheet(BuildContext context) {
    // Quick Add options — NO BackdropFilter (expensive full-screen blur removed)
    final lang =
        ref.watch(
          authStateProvider.select(
            (async) => async.valueOrNull?.preferredLanguage,
          ),
        ) ??
        'el';
    final s = S(lang);

    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? cs.surface : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: dark
                ? cs.outline.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.brand.neutralGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            lang == 'el' ? 'Γρήγορη Πρόσβαση' : 'Quick Access',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _QuickAddOption(
                  icon: Icons.note_add,
                  label: lang == 'el' ? 'Έξυπνες Σημειώσεις' : 'Smart Notes',
                  color: const Color(0xFFB1A2FB),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartNotesScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAddOption(
                  icon: Icons.auto_awesome,
                  label: lang == 'el' ? 'AI Βοηθός' : 'AI Tutor',
                  color: context.brand.royalLavender,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudyBuddyScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAddOption(
                  icon: Icons.quiz,
                  label: lang == 'el' ? 'Προσθήκη Διαγωνίσματος' : s.addExam,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExamTrackerScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Keeps tab subtree state alive when the page scrolls off-screen (mobile) or
/// is hidden with [Offstage] (desktop). Only the [_maxKeepAliveTabs] most
/// recently active tabs set [keepAlive] to true; older tabs are evicted to
/// free memory and reduce background provider activity.
class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const _KeepAliveTabWrapper({required this.child, required this.keepAlive});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void didUpdateWidget(_KeepAliveTabWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Isolates [totalUnreadCountProvider] so DM snapshot updates do not rebuild the
/// entire [HomeScaffold] (PageView, jelly scroll, FAB).
class _UnreadAwareFloatingIslandNav extends ConsumerWidget {
  final int selectedIndex;

  const _UnreadAwareFloatingIslandNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(
      authStateProvider.select((async) => async.valueOrNull?.uid),
    );
    final totalUnread = uid != null
        ? ref.watch(totalUnreadCountProvider(uid)).asData?.value ?? 0
        : 0;

    return FloatingIslandNav(
      selectedIndex: selectedIndex,
      onItemTapped: (index) {
        ref.read(navigationProvider.notifier).state = index;
      },
      badges: {3: totalUnread},
    );
  }
}

/// Hosts a [Widget] as a center-area overlay using a lightweight nested
/// [Navigator].  The overlay screen's own "back" / "close" buttons call
/// [Navigator.pop], which pops the overlay route back to the transparent base
/// route; [_OverlayPopObserver] detects this and clears [centerOverlayProvider].
/// No changes are needed inside the hosted screen.
class _CenterOverlayHost extends ConsumerStatefulWidget {
  final Widget overlay;
  const _CenterOverlayHost({required this.overlay});

  @override
  ConsumerState<_CenterOverlayHost> createState() => _CenterOverlayHostState();
}

class _CenterOverlayHostState extends ConsumerState<_CenterOverlayHost> {
  late final _OverlayPopObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = _OverlayPopObserver(
      onPopToBase: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(centerOverlayProvider.notifier).state = null;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Navigator(
        observers: [_observer],
        onGenerateInitialRoutes: (nav, name) => [
          // Opaque base fills the center column so the tab underneath never
          // shows through between routes or under transparent pages.
          MaterialPageRoute<void>(
            builder: (_) => ColoredBox(color: context.brand.backgroundSnow),
          ),
          MaterialPageRoute<void>(builder: (_) => widget.overlay),
        ],
      ),
    );
  }
}

/// Observes the nested [Navigator] inside [_CenterOverlayHost] and fires
/// [onPopToBase] when the overlay route is popped back to the base route.
class _OverlayPopObserver extends NavigatorObserver {
  final VoidCallback onPopToBase;
  _OverlayPopObserver({required this.onPopToBase});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // previousRoute.isFirst == true means only the transparent base remains
    // after the pop, i.e. the overlay screen was just dismissed.
    if (previousRoute != null && previousRoute.isFirst) {
      onPopToBase();
    }
  }
}

class _QuickAddOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

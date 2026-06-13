import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/core/constants/app_colors.dart';
import 'package:recruitment_app/features/notifications/application/notifications_provider.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';
import 'package:recruitment_app/features/auth/application/auth_providers.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({required this.child, super.key});

  final Widget child;

  static const _allTabs = <_TabSpec>[
    _TabSpec('/dashboard', 'Home', Icons.home_rounded, Icons.home_outlined),
    _TabSpec('/search', 'Search', Icons.search_rounded, Icons.search_outlined),
    _TabSpec('/feed', 'Jobs', Icons.work_rounded, Icons.work_outline_rounded),
    _TabSpec('/candidates', 'Candidates', Icons.people_alt_rounded, Icons.people_alt_outlined),
    _TabSpec('/pipeline', 'Pipeline', Icons.view_kanban_rounded, Icons.view_kanban_outlined),
    _TabSpec('/settings', 'Settings', Icons.settings_rounded, Icons.settings_outlined),
  ];

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  int _indexFromLocation(String location, List<_TabSpec> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      final path = tabs[i].path;
      if (location.startsWith(path)) return i;
      if (path == '/feed' && (location.startsWith('/jobs/') || location.startsWith('/feed'))) return i;
      if (path == '/candidates' && location.startsWith('/candidates/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    if (authState.dbUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final rawRole = authState.dbUser?.role?.toString().toUpperCase().trim();
    final isCandidate = rawRole == 'JOB_SEEKER';
    final isRecruiter = (rawRole == 'RECRUITER' ||
        rawRole == 'ADMIN' ||
        rawRole == 'HR_MANAGER' ||
        rawRole == 'COMPANY') && !isCandidate;

    final tabs = isCandidate
        ? const [
            _TabSpec('/dashboard', 'Home', Icons.home_rounded, Icons.home_outlined),
            _TabSpec('/feed', 'Jobs', Icons.work_rounded, Icons.work_outline_rounded),
            _TabSpec('/settings', 'Settings', Icons.settings_rounded, Icons.settings_outlined),
          ]
        : ShellScaffold._allTabs;

    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location, tabs);
    
    // Global real-time notification listener to showSnackbars/Toasts
    ref.listen<List<NotificationItem>>(notificationsProvider, (previous, next) {
      if (next.isNotEmpty && (previous == null || next.length > previous.length)) {
        final newNotif = next.first;

        // Skip stage change notifications if we're already on the pipeline screen
        final location = GoRouterState.of(context).uri.toString();
        if (location.startsWith('/pipeline') && newNotif.type == 'STAGE_CHANGED') {
          return;
        }

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                Icon(
                  newNotif.type == 'RESUME_PARSED'
                      ? Icons.auto_awesome_rounded
                      : newNotif.type == 'INTERVIEW_REMINDER'
                          ? Icons.alarm_rounded
                          : newNotif.type == 'CANDIDATE_APPLIED'
                              ? Icons.assignment_ind_rounded
                              : Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                     mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        newNotif.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        newNotif.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: PremiumMeshBackground(child: widget.child),
      floatingActionButton: isRecruiter
          ? FloatingActionButton(
              onPressed: () {
                context.push('/jobs/new');
              },
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              child: const Icon(Icons.auto_awesome_rounded),
            )
          : null,
      floatingActionButtonLocation: isRecruiter ? FloatingActionButtonLocation.centerDocked : null,
      bottomNavigationBar: _GlassNavBar(
        tabs: tabs,
        currentIndex: currentIndex,
        onTap: (index) => context.go(tabs[index].path),
      ),
    );
  }
}

class PremiumMeshBackground extends StatelessWidget {
  const PremiumMeshBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          color: isDark ? const Color(0xFF0A0914) : const Color(0xFFF4F6FC),
        ),
        Positioned(
          top: -80,
          left: -80,
          width: 380,
          height: 380,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.22 : 0.16),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -100,
          width: 420,
          height: 420,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.18 : 0.14),
            ),
          ),
        ),
        Positioned(
          top: 250,
          left: -150,
          width: 360,
          height: 360,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.14 : 0.10),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.72),
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35))),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              height: 72,
              selectedIndex: currentIndex,
              onDestinationSelected: onTap,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                return NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.path, this.label, this.selectedIcon, this.icon);
  final String path;
  final String label;
  final IconData selectedIcon;
  final IconData icon;
}

// ─── Notification Bell with Unread Badge ─────────────────────────────────────

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Badge(
      isLabelVisible: unreadCount > 0,
      label: Text('$unreadCount'),
      child: IconButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => const NotificationsBottomSheet(),
          );
        },
        icon: const Icon(Icons.notifications_rounded),
        tooltip: 'Notifications',
      ),
    );
  }
}

// ─── Notifications List Bottom Sheet ─────────────────────────────────────────

class NotificationsBottomSheet extends ConsumerWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final notifications = ref.watch(notificationsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(notificationsProvider.notifier).markAllAsRead();
                    },
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text('No new notifications', style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              height: 32,
                              width: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isRead
                                    ? cs.onSurfaceVariant.withValues(alpha: 0.1)
                                    : cs.primary.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                item.type == 'RESUME_PARSED'
                                    ? Icons.auto_awesome_rounded
                                    : item.type == 'INTERVIEW_REMINDER'
                                        ? Icons.alarm_rounded
                                        : Icons.info_outline_rounded,
                                size: 16,
                                color: item.isRead ? cs.onSurfaceVariant : cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    item.body,
                                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isRead)
                              IconButton(
                                onPressed: () {
                                  ref.read(notificationsProvider.notifier).markAsRead(item.id);
                                },
                                icon: const Icon(Icons.done_rounded, size: 18),
                                tooltip: 'Mark read',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

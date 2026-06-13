import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:recruitment_app/core/constants/app_colors.dart';
import 'package:recruitment_app/core/theme/theme_provider.dart';
import 'package:recruitment_app/features/auth/application/auth_providers.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final auth = ref.watch(authNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);

    final email = auth.dbUser?.email ?? auth.user?.email ?? 'Unknown';
    final displayName = auth.dbUser?.name ?? 'Recruiter';
    final initials = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

    String themeModeLabel(ThemeMode m) {
      switch (m) {
        case ThemeMode.system:
          return 'System';
        case ThemeMode.dark:
          return 'Dark';
        case ThemeMode.light:
          return 'Light';
      }
    }

    IconData themeModeIcon(ThemeMode m) {
      switch (m) {
        case ThemeMode.system:
          return Icons.brightness_auto_rounded;
        case ThemeMode.dark:
          return Icons.dark_mode_rounded;
        case ThemeMode.light:
          return Icons.light_mode_rounded;
      }
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Settings'),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed(
              [
                // ── Profile card ──
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: auth.dbUser?.avatarUrl == null || auth.dbUser!.avatarUrl!.isEmpty
                              ? const LinearGradient(colors: [AppColors.indigo, AppColors.cyan])
                              : null,
                          image: auth.dbUser?.avatarUrl != null && auth.dbUser!.avatarUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(auth.dbUser!.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: auth.dbUser?.avatarUrl == null || auth.dbUser!.avatarUrl!.isEmpty
                            ? Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

                const SizedBox(height: 10),

                // ── Edit Profile tile ──
                _SettingsTile(
                  icon: Icons.edit_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your display name',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showEditProfileSheet(context, ref, auth),
                ).animate().fadeIn(delay: 30.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

                const SizedBox(height: 10),

                // ── Theme selector ──
                _SettingsTile(
                  icon: themeModeIcon(themeMode),
                  title: 'Theme',
                  subtitle: themeModeLabel(themeMode),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 16)),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 16)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 16)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (sel) {
                      ref.read(themeModeProvider.notifier).setThemeMode(sel.first);
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

                const SizedBox(height: 10),

                // ── Notifications ──
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  subtitle: 'Manage push & email alerts',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showNotificationsSheet(context, ref),
                ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

                const SizedBox(height: 10),

                // ── About ──
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'AI Recruiter v1.0.0',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showAboutSheet(context),
                ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

                const SizedBox(height: 24),

                // ── Sign-out ──
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(Icons.logout_rounded, color: cs.error),
                      title: Text(
                        'Sign out',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.error,
                        ),
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out?'),
                            content: const Text('Are you sure you want to sign out?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await ref.read(authNotifierProvider.notifier).signOut();
                          if (context.mounted) context.go('/login');
                        }
                      },
                    ),
                  ),
                ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _NotificationsSheet(),
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, AppAuthState auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditProfileSheet(auth: auth),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.auth});
  final AppAuthState auth;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  PlatformFile? _selectedPhoto;
  bool _saving = false;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.auth.dbUser?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedPhoto = result.files.first;
          _removePhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatarUrl = widget.auth.dbUser?.avatarUrl;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
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
          Text(
            'Edit Profile',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),

          // Photo Picker Widget
          Center(
            child: Stack(
              children: [
                Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.indigo, AppColors.cyan]),
                    image: !_removePhoto && _selectedPhoto != null && _selectedPhoto!.bytes != null
                        ? DecorationImage(
                            image: MemoryImage(_selectedPhoto!.bytes!),
                            fit: BoxFit.cover,
                          )
                        : !_removePhoto && avatarUrl != null && avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: (_removePhoto || (_selectedPhoto == null && (avatarUrl == null || avatarUrl.isEmpty)))
                      ? const Center(
                          child: Icon(Icons.person_rounded, size: 48, color: Colors.white),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: cs.primary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      onTap: _pickPhoto,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_removePhoto && (_selectedPhoto != null || (avatarUrl != null && avatarUrl.isNotEmpty)))
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Material(
                      color: cs.error,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPhoto = null;
                            _removePhoto = true;
                          });
                        },
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: widget.auth.dbUser?.email ?? widget.auth.user?.email ?? 'admin@local.test',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final newName = _nameController.text.trim();
                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name cannot be empty')),
                            );
                            return;
                          }
                          setState(() => _saving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          try {
                            String? finalAvatarUrl = avatarUrl;
                            if (_removePhoto) {
                              finalAvatarUrl = '';
                            } else if (_selectedPhoto != null && _selectedPhoto!.bytes != null) {
                              finalAvatarUrl = await ref
                                  .read(authNotifierProvider.notifier)
                                  .uploadAvatar(
                                    fileName: _selectedPhoto!.name,
                                    fileBytes: _selectedPhoto!.bytes!,
                                  );
                            }
                            final success = await ref
                                .read(authNotifierProvider.notifier)
                                .updateProfile(
                                  name: newName,
                                  avatarUrl: finalAvatarUrl,
                                );
                            if (mounted) {
                              setState(() => _saving = false);
                              if (success) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully')),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Failed to update profile')),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _saving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Upload failed: $e')),
                              );
                            }
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Notifications bottom sheet ───────────────────────────────────────────────

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _newCandidates = true;
  bool _resumeParsed = true;
  bool _interviewReminders = true;
  bool _statusChanges = false;
  bool _weeklyDigest = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            Text(
              'Notification Preferences',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what you want to be notified about.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _NotifToggle(
              title: 'New candidates',
              subtitle: 'When a candidate applies or is added',
              value: _newCandidates,
              onChanged: (v) => setState(() => _newCandidates = v),
            ),
            _NotifToggle(
              title: 'Resume parsed',
              subtitle: 'When AI finishes parsing a resume',
              value: _resumeParsed,
              onChanged: (v) => setState(() => _resumeParsed = v),
            ),
            _NotifToggle(
              title: 'Interview reminders',
              subtitle: '30 min before a scheduled interview',
              value: _interviewReminders,
              onChanged: (v) => setState(() => _interviewReminders = v),
            ),
            _NotifToggle(
              title: 'Pipeline changes',
              subtitle: 'When a candidate moves stages',
              value: _statusChanges,
              onChanged: (v) => setState(() => _statusChanges = v),
            ),
            _NotifToggle(
              title: 'Weekly digest',
              subtitle: 'Summary of hiring activity each Monday',
              value: _weeklyDigest,
              onChanged: (v) => setState(() => _weeklyDigest = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification preferences saved')),
                  );
                },
                child: const Text('Save preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifToggle extends StatelessWidget {
  const _NotifToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ─── Shared settings tile ─────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: cs.primary.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─── Custom About Bottom Sheet ───────────────────────────────────────────────

void _showAboutSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _AboutSheet(),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Recruiter',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Version 1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'A premium, state-of-the-art recruitment platform featuring AI semantic resume parsing, culture-fit scoring, and interactive candidate pipeline management.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2026 AI Recruiter. All Rights Reserved.',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCustomLicensesSheet(context);
                    },
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text('View Licenses'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Licenses Bottom Sheet ───────────────────────────────────────────

void _showCustomLicensesSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _CustomLicensesSheet(),
  );
}

class _CustomLicensesSheet extends StatelessWidget {
  const _CustomLicensesSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final categories = [
      _LicenseCategory(
        title: 'AI RECRUITER SOFTWARE',
        subtitle: 'End-User License Agreement (EULA)',
        icon: Icons.gavel_rounded,
        text: '''
Copyright (c) 2026 AI Recruiter. All Rights Reserved.

1. LICENSE GRANT
AI Recruiter grants you a non-exclusive, non-transferable, revocable license to use this software solely for internal business operations and hiring management.

2. RESTRICTIONS
You agree not to sell, redistribute, reverse-engineer, or modify the Software binaries or core APIs.
''',
      ),
      _LicenseCategory(
        title: 'AI RECRUITER BRAND ASSETS',
        subtitle: 'Proprietary visual designs & identity',
        icon: Icons.palette_rounded,
        text: '''
Copyright (c) 2026 AI Recruiter. All Rights Reserved.

All proprietary mesh gradients, animations, glassmorphic themes, and brand logos are protected intellectual property. These may not be extracted or repackaged in external commercial works.
''',
      ),
      _LicenseCategory(
        title: 'FLUTTER',
        subtitle: 'Underlying UI framework & engine',
        icon: Icons.flutter_dash_rounded,
        text: '''
Copyright 2014 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the conditions of the BSD 3-Clause License are met.
''',
      ),
      _LicenseCategory(
        title: 'DEVELOPMENT',
        subtitle: 'Riverpod, Dio, Google Fonts, and Dotenv',
        icon: Icons.code_rounded,
        text: '''
This application utilizes open-source libraries under MIT and Apache 2.0 licenses:
- Riverpod: State management (MIT)
- Dio: HTTP Networking client (MIT)
- Google Fonts: Modern typography (OFL)
- Dotenv: Environment configuration (BSD)
''',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            Text(
              'Software Licenses',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Compliance and legal agreements arranged by category.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Icon(cat.icon, color: cs.primary),
                          title: Text(
                            cat.title,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            cat.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cat.text,
                                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _LicenseCategory {
  const _LicenseCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.text,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String text;
}

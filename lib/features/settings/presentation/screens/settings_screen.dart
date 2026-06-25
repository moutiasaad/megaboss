import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../../../core/widgets/section_label.dart';

// ── Settings screen ────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;
  bool _isLoggingOut = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = 'v${info.version}');
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickLocale(AppStrings s, Locale locale) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LocaleSheet(current: locale.languageCode, s: s),
    );
    if (picked != null && picked != locale.languageCode) {
      await ref.read(localeProvider.notifier).setLocale(picked);
    }
  }

  Future<void> _pickTheme(AppStrings s, ThemeMode current) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ThemeSheet(current: current, s: s),
    );
    if (picked != null && picked != current) {
      await ref.read(themeModeProvider.notifier).setMode(picked);
    }
  }

  Future<void> _togglePush(bool enabled) async {
    HapticFeedback.lightImpact();
    await ref.read(pushEnabledProvider.notifier).setEnabled(enabled);
    try {
      if (enabled) {
        await FirebaseMessaging.instance.subscribeToTopic('driver_all');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('driver_all');
      }
    } catch (_) {}
  }

  Future<void> _forceSync(AppStrings s) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncPushServiceProvider).flush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.setSyncSuccessToast)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.setSyncErrorToast)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _confirmLogout(AppStrings s, int pending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.setLogoutTitle,
            style: MbTypography.h3(Theme.of(ctx).colorScheme.onSurface)),
        content: pending > 0
            ? Text(s.setLogoutUnsyncedWarn(pending),
                style: MbTypography.body(mbRed))
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.setLogoutCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.setLogoutConfirm,
                style: TextStyle(color: mbRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await ref.read(fcmRegistrationServiceProvider).stop();
      await repo.unregisterDevice();
      await repo.logout();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.setLogoutError)),
        );
        setState(() => _isLoggingOut = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = AppStrings.of(locale.languageCode);
    final themeMode = ref.watch(themeModeProvider);
    final pushEnabled = ref.watch(pushEnabledProvider);
    final pendingAsync = ref.watch(pendingOpsCountProvider);
    final driver = ref.watch(currentDriverProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = locale.languageCode == 'ar';

    final pending = pendingAsync.valueOrNull ?? 0;
    final isOffline = pendingAsync is AsyncError;

    final themeLabel = switch (themeMode) {
      ThemeMode.light => s.setThemeLight,
      ThemeMode.dark => s.setThemeDark,
      ThemeMode.system => s.setThemeSystem,
    };
    final langLabel = switch (locale.languageCode) {
      'ar' => s.setLangValueAr,
      'en' => s.setLangValueEn,
      _ => s.setLangValueFr,
    };

    return Scaffold(
      backgroundColor: isDark ? mbDarkBg : mbSurface2,
      body: Column(
        children: [
          _SettingsAppBar(title: s.setTitle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: MbSpacing.md2, vertical: MbSpacing.md2),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // (B) Profile card
                      _ProfileCard(
                        driver: driver,
                        appVersion: _appVersion,
                      ),
                      const SizedBox(height: 18),

                      // (C) Preferences
                      SectionLabel(s.setSectionPrefs),
                      MbCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SettingRow.value(
                              icon: Icons.language_rounded,
                              title: s.setLang,
                              value: langLabel,
                              isRtl: isRtl,
                              onTap: () => _pickLocale(s, locale),
                            ),
                            _RowDivider(isDark: isDark),
                            _SettingRow.value(
                              icon: Icons.wb_sunny_rounded,
                              title: s.setTheme,
                              subtitle: s.setThemeSub,
                              value: themeLabel,
                              isRtl: isRtl,
                              onTap: () => _pickTheme(s, themeMode),
                            ),
                            _RowDivider(isDark: isDark),
                            _SettingRow.toggle(
                              icon: Icons.notifications_rounded,
                              title: s.setPush,
                              value: pushEnabled,
                              isRtl: isRtl,
                              onChanged: _togglePush,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // (D) Sync
                      SectionLabel(s.setSectionSync),
                      MbCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SyncStateRow(
                              pending: pending,
                              isOffline: isOffline,
                              isSyncing: _isSyncing,
                              s: s,
                              isDark: isDark,
                            ),
                            _RowDivider(isDark: isDark),
                            _ForceSyncRow(
                              isSyncing: _isSyncing,
                              isOffline: isOffline,
                              s: s,
                              isDark: isDark,
                              onTap: () => _forceSync(s),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // (E) Logout
                      _LogoutButton(
                        label: s.setLogout,
                        isLoading: _isLoggingOut,
                        onTap: () => _confirmLogout(s, pending),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _SettingsAppBar extends StatelessWidget {
  const _SettingsAppBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                title,
                style: GoogleFonts.archivo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Profile card ───────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.driver, required this.appVersion});

  final dynamic driver;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = driver?.name as String? ?? '—';
    final initials = driver?.initials as String? ?? '?';
    final role = driver?.role as String? ?? 'livreur';
    final city = driver?.city as String? ?? '';
    final subLine = [
      role,
      if (city.isNotEmpty) city,
      if (appVersion.isNotEmpty) appVersion,
    ].join(' · ');

    return MbCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: mbBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.archivo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: MbTypography.h3(isDark ? mbDarkInk : mbInk)),
                const SizedBox(height: 2),
                Text(
                  subLine,
                  style: MbTypography.cap(isDark ? mbDarkInk2 : mbInk2),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row divider ────────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? mbDarkLine2 : mbLine2,
    );
  }
}

// ── Setting row ────────────────────────────────────────────────────────────────

enum _SettingRowType { value, toggle }

class _SettingRow extends StatelessWidget {
  const _SettingRow._({
    required this.type,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.toggleValue = false,
    this.isRtl = false,
    this.onTap,
    this.onChanged,
  });

  factory _SettingRow.value({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    bool isRtl = false,
    VoidCallback? onTap,
  }) =>
      _SettingRow._(
        type: _SettingRowType.value,
        icon: icon,
        title: title,
        subtitle: subtitle,
        value: value,
        isRtl: isRtl,
        onTap: onTap,
      );

  factory _SettingRow.toggle({
    required IconData icon,
    required String title,
    required bool value,
    bool isRtl = false,
    ValueChanged<bool>? onChanged,
  }) =>
      _SettingRow._(
        type: _SettingRowType.toggle,
        icon: icon,
        title: title,
        toggleValue: value,
        isRtl: isRtl,
        onChanged: onChanged,
      );

  final _SettingRowType type;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final bool toggleValue;
  final bool isRtl;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF2A3340) : mbSurface3;
    final inkColor = isDark ? mbDarkInk : mbInk;
    final ink2Color = isDark ? mbDarkInk2 : mbInk2;
    final ink3Color = isDark ? mbDarkInk3 : mbInk3;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: mbBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.archivo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: inkColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!,
                      style: MbTypography.cap(ink3Color)),
                ],
              ],
            ),
          ),
          if (type == _SettingRowType.value)
            Text(
              isRtl ? '‹ $value' : '$value ›',
              style: MbTypography.sub(ink2Color)
                  .copyWith(fontWeight: FontWeight.w600),
            )
          else
            Semantics(
              toggled: toggleValue,
              label: title,
              child: Switch(
                value: toggleValue,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: mbBlue,
                inactiveTrackColor: isDark ? mbDarkLine : mbLine,
                inactiveThumbColor: Colors.white,
              ),
            ),
        ],
      ),
    );

    if (type == _SettingRowType.value && onTap != null) {
      row = InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: title,
          value: value,
          child: row,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMbMinTouchTarget),
      child: row,
    );
  }
}

// ── Sync state row ─────────────────────────────────────────────────────────────

class _SyncStateRow extends StatelessWidget {
  const _SyncStateRow({
    required this.pending,
    required this.isOffline,
    required this.isSyncing,
    required this.s,
    required this.isDark,
  });

  final int pending;
  final bool isOffline;
  final bool isSyncing;
  final AppStrings s;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark ? const Color(0xFF2A3340) : mbSurface3;
    final inkColor = isDark ? mbDarkInk : mbInk;
    final ink3Color = isDark ? mbDarkInk3 : mbInk3;

    final subtitle = isOffline
        ? s.setSyncOfflinePending(pending)
        : pending > 0
            ? s.setSyncPending(pending, '2 min')
            : s.setSyncUpToDate;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMbMinTouchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.sync_rounded, size: 17, color: mbBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.setSyncState,
                    style: GoogleFonts.archivo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(subtitle, style: MbTypography.cap(ink3Color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Force sync row ─────────────────────────────────────────────────────────────

class _ForceSyncRow extends StatelessWidget {
  const _ForceSyncRow({
    required this.isSyncing,
    required this.isOffline,
    required this.s,
    required this.isDark,
    required this.onTap,
  });

  final bool isSyncing;
  final bool isOffline;
  final AppStrings s;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark ? const Color(0xFF2A3340) : mbSurface3;
    final isDisabled = isOffline || isSyncing;

    return InkWell(
      onTap: isDisabled ? null : onTap,
      child: Semantics(
        button: true,
        label: s.setForceSync,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMbMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(mbBlue),
                          ),
                        )
                      : Icon(
                          Icons.sync_rounded,
                          size: 17,
                          color: isDisabled
                              ? (isDark ? mbDarkInk3 : mbInk3)
                              : mbBlue,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isSyncing ? s.setSyncing : s.setForceSync,
                    style: GoogleFonts.archivo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDisabled
                          ? (isDark ? mbDarkInk3 : mbInk3)
                          : mbBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logout button ──────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: mbRed,
          side: const BorderSide(color: mbRed, width: 1.5),
          minimumSize: const Size.fromHeight(kMbMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MbRadius.button),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(mbRed),
                ),
              )
            : const Icon(Icons.logout_rounded, size: 16),
        label: Text(
          label,
          style: GoogleFonts.archivo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: mbRed,
          ),
        ),
      ),
    );
  }
}

// ── Locale picker sheet ────────────────────────────────────────────────────────

class _LocaleSheet extends StatelessWidget {
  const _LocaleSheet({required this.current, required this.s});
  final String current;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? mbDarkSurface : mbSurface;
    final options = [
      ('fr', s.setLangValueFr, '🇫🇷'),
      ('ar', s.setLangValueAr, '🇲🇦'),
      ('en', s.setLangValueEn, '🇬🇧'),
    ];

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MbRadius.bottomSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? mbDarkLine : mbLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...options.map((opt) {
              final (code, label, flag) = opt;
              final isSelected = current == code;
              return ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 22)),
                title: Text(label, style: MbTypography.h3(isDark ? mbDarkInk : mbInk)),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: mbBlue)
                    : null,
                onTap: () => Navigator.of(context).pop(code),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Theme picker sheet ─────────────────────────────────────────────────────────

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current, required this.s});
  final ThemeMode current;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? mbDarkSurface : mbSurface;
    final options = [
      (ThemeMode.light, s.setThemeLight, Icons.wb_sunny_rounded),
      (ThemeMode.dark, s.setThemeDark, Icons.nights_stay_rounded),
      (ThemeMode.system, s.setThemeSystem, Icons.brightness_auto_rounded),
    ];

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MbRadius.bottomSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? mbDarkLine : mbLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...options.map((opt) {
              final (mode, label, icon) = opt;
              final isSelected = current == mode;
              return ListTile(
                leading: Icon(
                  icon,
                  color: isSelected ? mbBlue : (isDark ? mbDarkInk3 : mbInk3),
                ),
                title: Text(label, style: MbTypography.h3(isDark ? mbDarkInk : mbInk)),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: mbBlue)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

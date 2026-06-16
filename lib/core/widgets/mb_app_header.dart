import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../i18n/app_strings.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class MbAppHeader extends ConsumerWidget {
  const MbAppHeader({
    super.key,
    required this.driverName,
    required this.isAvailable,
    required this.pendingSyncOps,
    required this.strings,
    this.onBell,
    this.onSyncTap,
    this.unreadNotifications = 0,
  });

  final String driverName;
  final bool isAvailable;
  final int pendingSyncOps;
  final AppStrings strings;
  final VoidCallback? onBell;
  final VoidCallback? onSyncTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MbSpacing.lg,
            MbSpacing.sm,
            MbSpacing.lg,
            MbSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1 — logo + bell
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_white.png',
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  _BellButton(
                    unreadCount: unreadNotifications,
                    onTap: onBell,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              // Row 2 — greeting + status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.dashHello,
                        style: MbTypography.sub(
                          const Color(0xFFBCD3EA),
                        ),
                      ),
                      Text(
                        driverName,
                        style: MbTypography.h2(Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _StatusPill(
                    label: isAvailable
                        ? strings.dashStatusAvailable
                        : strings.dashStatusUnavailable,
                    isAvailable: isAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 3 — sync tag
              _SyncTag(
                pendingCount: pendingSyncOps,
                strings: strings,
                onTap: onSyncTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bell button ────────────────────────────────────────────────────────────────

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unreadCount, this.onTap});
  final int unreadCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications${unreadCount > 0 ? ', $unreadCount non lues' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(0x24),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 17,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: mbRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.isAvailable});
  final String label;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? mbOk : mbWarn,
        borderRadius: BorderRadius.circular(MbRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sync tag ───────────────────────────────────────────────────────────────────

class _SyncTag extends StatelessWidget {
  const _SyncTag({
    required this.pendingCount,
    required this.strings,
    this.onTap,
  });
  final int pendingCount;
  final AppStrings strings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSynced = pendingCount == 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(0x1F),
          borderRadius: BorderRadius.circular(MbRadius.chip),
          border: Border.all(
            color: Colors.white.withAlpha(0x2E),
            width: 1,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(pendingCount),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSynced ? Icons.check_circle_outline : Icons.sync,
                size: 13,
                color: const Color(0xFFDCEAF7),
              ),
              const SizedBox(width: 5),
              Text(
                isSynced
                    ? strings.dashSyncUptodate
                    : strings.dashSyncPending(pendingCount),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDCEAF7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

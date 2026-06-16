import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/mb_card.dart';
import '../../data/models/notif_entry.dart';
import '../controllers/notifications_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollCtrl = ScrollController();
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _reduceMotion = WidgetsBinding.instance
              .platformDispatcher.accessibilityFeatures.disableAnimations;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMarkAllRead(AppStrings s) async {
    await HapticFeedback.lightImpact();
    await ref.read(notificationsProvider.notifier).markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final s = AppStrings.of(locale);
    final notifsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasUnread = (notifsAsync.valueOrNull?.unread ?? 0) > 0;
    final isOffline = notifsAsync.valueOrNull?.offline ?? false;

    return Scaffold(
      backgroundColor: isDark ? mbDarkBg : mbSurface2,
      body: Column(
        children: [
          _NotifAppBar(
            strings: s,
            hasUnread: hasUnread,
            onMarkAllRead: () => _onMarkAllRead(s),
          ),
          if (isOffline)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: _OfflineBanner(strings: s),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: notifsAsync.when(
                data: (state) => _buildData(context, s, state, isDark),
                loading: () =>
                    _NotifSkeleton(key: const ValueKey('sk'), isDark: isDark),
                error: (_, __) => _buildError(s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    AppStrings s,
    NotifState state,
    bool isDark,
  ) {
    if (state.items.isEmpty) return _buildEmpty(s);

    // Group items by day.
    final groups = _groupByDay(state.items, s);

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      color: mbBlue,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        child: MbCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in groups) ...[
                if (group.label != null) _DayHeader(label: group.label!, isDark: isDark),
                for (int i = 0; i < group.entries.length; i++) ...[
                  if (i > 0 || group.label != null)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? mbDarkLine2 : mbLine2,
                    ),
                  _NotifRow(
                    key: ValueKey(group.entries[i].id),
                    entry: group.entries[i],
                    strings: s,
                    reduceMotion: _reduceMotion,
                    animDelay: Duration(
                        milliseconds: 40 * _globalIndex(groups, group, i)),
                    onTap: () => _onTap(group.entries[i]),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(NotifEntry entry) {
    ref.read(notificationsProvider.notifier).markRead(entry.id);
    final link = entry.deeplink;
    if (link != null && link.isNotEmpty) {
      context.push(link);
    }
  }

  Widget _buildEmpty(AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MbSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 56, color: mbInk3),
            const SizedBox(height: MbSpacing.md),
            Text(s.notifEmptyTitle,
                style: MbTypography.h3(mbInk2), textAlign: TextAlign.center),
            const SizedBox(height: MbSpacing.xs),
            Text(s.notifEmptyBody,
                style: MbTypography.sub(mbInk3), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MbSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: mbErr),
            const SizedBox(height: MbSpacing.md),
            Text(s.notifError,
                style: MbTypography.h3(mbErr), textAlign: TextAlign.center),
            const SizedBox(height: MbSpacing.lg),
            FilledButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: Text(s.dashRetry),
            ),
          ],
        ),
      ),
    );
  }

  // Returns the flat index of an entry across all groups (for anim delay).
  int _globalIndex(
      List<_DayGroup> groups, _DayGroup group, int indexInGroup) {
    var count = 0;
    for (final g in groups) {
      if (g == group) return count + indexInGroup;
      count += g.entries.length;
    }
    return count + indexInGroup;
  }
}

// ── Day grouping ───────────────────────────────────────────────────────────────

class _DayGroup {
  const _DayGroup({this.label, required this.entries});
  final String? label;
  final List<NotifEntry> entries;
}

List<_DayGroup> _groupByDay(List<NotifEntry> items, AppStrings s) {
  final now = DateTime.now();
  final todayKey = _dayKey(now);
  final yesterdayKey = _dayKey(now.subtract(const Duration(days: 1)));

  final Map<String, List<NotifEntry>> buckets = {};
  for (final e in items) {
    final key = _dayKey(e.timestamp.toLocal());
    buckets.putIfAbsent(key, () => []).add(e);
  }

  return buckets.entries.map((e) {
    String? label;
    if (e.key == todayKey) {
      label = s.notifGroupToday;
    } else if (e.key == yesterdayKey) {
      label = s.notifGroupYesterday;
    } else {
      label = s.notifGroupOlder;
    }
    return _DayGroup(label: label, entries: e.value);
  }).toList();
}

String _dayKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

// ── App bar ────────────────────────────────────────────────────────────────────

class _NotifAppBar extends StatelessWidget {
  const _NotifAppBar({
    required this.strings,
    required this.hasUnread,
    required this.onMarkAllRead,
  });
  final AppStrings strings;
  final bool hasUnread;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    // Color for the "Tout consulter" action — dimmed when nothing unread.
    const actionColor = Color(0xFFCFE0F1);
    final actionDimmed = actionColor.withAlpha(0x66);

    return Container(
      color: mbBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              // Back
              Semantics(
                button: true,
                label: strings.scanBack,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      strings.isRtl
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              // Title
              Text(
                strings.notifTitle,
                style: GoogleFonts.archivo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Mark all read
              Semantics(
                button: true,
                enabled: hasUnread,
                label: strings.notifMarkAllRead,
                child: GestureDetector(
                  onTap: hasUnread ? onMarkAllRead : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Text(
                      strings.notifMarkAllRead,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: hasUnread ? actionColor : actionDimmed,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: mbWarnBg,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(color: mbWarn.withAlpha(0x66), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: mbWarn, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.notifOfflineCache,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: mbWarn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day group header ───────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.archivo(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isDark ? mbDarkInk3 : mbInk3,
        ),
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

class _NotifSkeleton extends StatefulWidget {
  const _NotifSkeleton({super.key, required this.isDark});
  final bool isDark;

  @override
  State<_NotifSkeleton> createState() => _NotifSkeletonState();
}

class _NotifSkeletonState extends State<_NotifSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark ? mbDarkSurface2 : mbSurface3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? mbDarkSurface : mbSurface,
              borderRadius: BorderRadius.circular(MbRadius.card),
              border: Border.all(
                  color: widget.isDark ? mbDarkLine : mbLine, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (int i = 0; i < 5; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: widget.isDark ? mbDarkLine2 : mbLine2,
                    ),
                  _SkeletonRow(base: base),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.base});
  final Color base;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 200,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 150,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification row ───────────────────────────────────────────────────────────

class _NotifRow extends StatefulWidget {
  const _NotifRow({
    super.key,
    required this.entry,
    required this.strings,
    required this.reduceMotion,
    required this.animDelay,
    required this.onTap,
  });
  final NotifEntry entry;
  final AppStrings strings;
  final bool reduceMotion;
  final Duration animDelay;
  final VoidCallback onTap;

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 10.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.reduceMotion || widget.animDelay == Duration.zero) {
      _ctrl.value = 1.0;
    } else {
      Future.delayed(widget.animDelay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final s = widget.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColors = Theme.of(context).extension<MbStatusColors>()!;

    // Icon style per type
    final iconStyle = _iconStyle(e.type, statusColors, isDark);
    final iconBg = iconStyle.bg;
    final iconColor = iconStyle.fg;
    final iconData = iconStyle.icon;

    final relTime = _relativeTime(e.timestamp, s);

    final semanticLabel =
        '${e.title}, ${e.subtitle}, $relTime${e.read ? '' : ', ${s.notifUnread}'}';

    Widget rowBody = Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: e.read ? 0.55 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon (36×36, radius 11)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(iconData, color: iconColor, size: 18),
                ),
                const SizedBox(width: 11),
                // Middle: title (with unread dot) + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with inline unread dot
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              e.title,
                              style: GoogleFonts.archivo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: isDark ? mbDarkInk : mbInk,
                              ),
                            ),
                          ),
                          if (!e.read) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: mbRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.subtitle} · $relTime',
                        style: GoogleFonts.splineSansMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? mbDarkInk3 : mbInk3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.reduceMotion) return rowBody;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slideY.value),
          child: child,
        ),
      ),
      child: rowBody,
    );
  }

  ({Color bg, Color fg, IconData icon}) _iconStyle(
    NotifType type,
    MbStatusColors sc,
    bool isDark,
  ) {
    return switch (type) {
      NotifType.runsheetNew || NotifType.runsheetClosed => (
          bg: sc.pendBg,
          fg: sc.pend,
          icon: Icons.description_outlined,
        ),
      NotifType.pickupNew => (
          bg: sc.okBg,
          fg: sc.ok,
          icon: Icons.local_shipping_outlined,
        ),
      NotifType.shipmentAdded => (
          bg: sc.errBg,
          fg: sc.err,
          icon: Icons.add_box_outlined,
        ),
      NotifType.system => (
          bg: isDark ? mbDarkSurface2 : mbSurface3,
          fg: isDark ? mbDarkInk2 : mbInk2,
          icon: Icons.info_outline,
        ),
    };
  }
}

// ── Relative time ──────────────────────────────────────────────────────────────

String _relativeTime(DateTime ts, AppStrings s) {
  final now = DateTime.now();
  final diff = now.difference(ts.toLocal());

  if (diff.inMinutes < 1) return s.notifTimeJustNow;
  if (diff.inMinutes < 60) return s.notifTimeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return s.notifTimeHours(diff.inHours);

  final local = ts.toLocal();
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${s.notifTimeYesterday} · $hh:$mm';
  }

  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

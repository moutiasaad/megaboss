import 'package:flutter/material.dart';
import '../i18n/app_strings.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class MbOfflineBanner extends StatelessWidget {
  const MbOfflineBanner({
    super.key,
    required this.strings,
    required this.pendingCount,
  });

  final AppStrings strings;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: MbSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: MbSpacing.md,
        vertical: MbSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: mbWarnBg,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(color: mbWarn.withAlpha(0x66), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: mbWarn, size: 15),
          const SizedBox(width: MbSpacing.xs),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? '${strings.dashOfflineCache} · ${strings.dashSyncPending(pendingCount)}'
                  : strings.dashOfflineCache,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class MbSegmentedItem<T> {
  const MbSegmentedItem({required this.value, required this.label});
  final T value;
  final String label;
}

class MbSegmented<T> extends StatelessWidget {
  const MbSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<MbSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? mbDarkSurface2 : mbSurface3,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: items.map((item) {
          final isActive = item.value == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(item.value);
              },
              child: Semantics(
                selected: isActive,
                label: '${item.label}, filtre',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDark ? mbDarkSurface : mbSurface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isActive
                        ? const [
                            BoxShadow(
                              color: Color(0x1F142850),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? (isDark ? Colors.white : mbBlue)
                          : (isDark ? mbDarkInk2 : mbInk2),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

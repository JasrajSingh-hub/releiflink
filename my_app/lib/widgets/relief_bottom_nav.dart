import 'package:flutter/material.dart';

class ReliefBottomNav extends StatelessWidget {
  const ReliefBottomNav({
    super.key,
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Item(
              label: 'Home',
              icon: Icons.home_filled,
              isActive: index == 0,
              onTap: () => onSelect(0),
            ),
            _Item(
              label: 'Requests',
              icon: Icons.format_list_bulleted,
              isActive: index == 1,
              onTap: () => onSelect(1),
            ),
            _Item(
              label: 'Create',
              icon: Icons.add_circle,
              isActive: index == 2,
              onTap: () => onSelect(2),
            ),
            _Item(
              label: 'Map',
              icon: Icons.map,
              isActive: index == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? Colors.white : const Color(0xFF52525B);
    final bg = isActive ? const Color(0xFF111827) : Colors.transparent;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
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


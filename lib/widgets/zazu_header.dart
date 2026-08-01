import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class ZazuHeader extends StatelessWidget {
  const ZazuHeader({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720 || size.width < 370;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0])
        .join()
        .toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.paddingOf(context).top + (compact ? 12 : 18),
        22,
        compact ? 20 : 26,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6520DB), AppTheme.purple, Color(0xFF992BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 42 : 48,
                      height: compact ? 42 : 48,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121024).withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset('assets/images/zazu_logo.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ZAZU Driver',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 22),
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: .92),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 25 : 29,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: compact ? 56 : 64,
            height: compact ? 56 : 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials.isEmpty ? 'ZD' : initials,
              style: TextStyle(fontSize: compact ? 18 : 21, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días,';
    if (hour < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }
}

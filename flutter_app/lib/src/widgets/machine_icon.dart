import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/machine.dart';

class MachineIcon extends StatelessWidget {
  const MachineIcon({
    super.key,
    required this.machine,
    this.size = 28,
  });

  final Machine machine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = machine.isWasher
        ? const Color(0xFFD7F0FF)
        : const Color(0xFFFFE8CC);
    final tint = machine.isWasher
        ? const Color(0xFF0E7490)
        : const Color(0xFFC86B3C);

    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(10),
      child: SvgPicture.asset(
        machine.iconAsset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}

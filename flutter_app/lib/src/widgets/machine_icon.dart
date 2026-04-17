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
    final Color background;
    final Color tint;
    final Widget icon;

    if (machine.isWasher) {
      background = const Color(0xFFD7F0FF);
      tint = const Color(0xFF0E7490);
      icon = SvgPicture.asset(
        machine.iconAsset!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      );
    } else if (machine.isDryer) {
      background = const Color(0xFFFFE8CC);
      tint = const Color(0xFFC86B3C);
      icon = SvgPicture.asset(
        machine.iconAsset!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      );
    } else {
      background = const Color(0xFFE6F7EB);
      tint = const Color(0xFF2F855A);
      icon = Icon(
        Icons.iron_outlined,
        size: size,
        color: tint,
      );
    }

    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(10),
      child: icon,
    );
  }
}

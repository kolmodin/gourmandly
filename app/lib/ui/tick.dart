import 'package:flutter/material.dart';

import 'theme.dart';

/// A round tick, like the plates.
class RoundTick extends StatelessWidget {
  const RoundTick({required this.ticked, super.key});

  final bool ticked;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: ticked ? Palette.cobalt : Palette.plate,
      border: Border.all(color: Palette.cobalt, width: 2),
    ),
    child: ticked
        ? const Icon(Icons.check, size: 16, color: Palette.plate)
        : null,
  );
}

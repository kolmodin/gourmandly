import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'theme.dart';

/// A recipe's photo as a plate: the food in the well, an enamel rim around it.
/// The rim tells where the recipe is: cobalt, or saffron while it's cooking. A
/// recipe without a photo is an empty plate.
class Plate extends ConsumerWidget {
  const Plate({required this.recipe, this.rim = Palette.cobalt, super.key});

  final Recipe recipe;
  final Color rim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = recipe.image?.storagePath;
    final url = path == null ? null : ref.watch(photoUrlProvider(path)).value;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.plate,
              border: Border.all(color: rim, width: size * 0.016 + 1),
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.045),
              child: ClipOval(
                child: url == null
                    ? const _EmptyWell()
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        semanticLabel: recipe.title,
                        errorBuilder: (context, error, stackTrace) =>
                            const _EmptyWell(),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyWell extends StatelessWidget {
  const _EmptyWell();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Palette.plate,
      border: Border.fromBorderSide(BorderSide(color: Palette.hairline)),
    ),
    child: SizedBox.expand(),
  );
}

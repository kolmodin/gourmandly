import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'theme.dart';

/// A recipe's photo, square with slightly rounded corners, as on the recipe
/// sites people know. A label in a corner tells where a planned recipe is. A
/// recipe without a photo gets an empty tile.
class RecipePhoto extends ConsumerWidget {
  const RecipePhoto({
    required this.recipe,
    this.label,
    this.labelAtBottom = false,
    this.radius = 6,
    super.key,
  });

  final Recipe recipe;
  final PhotoLabel? label;
  final bool labelAtBottom;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = recipe.image?.storagePath;
    final url = path == null ? null : ref.watch(photoUrlProvider(path)).value;
    final label = this.label;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            const _Empty()
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: recipe.title,
              errorBuilder: (context, error, stackTrace) => const _Empty(),
            ),
          if (label != null)
            Positioned(
              left: 0,
              top: labelAtBottom ? null : 0,
              bottom: labelAtBottom ? 0 : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: label.background,
                  borderRadius: labelAtBottom
                      ? BorderRadius.only(topRight: Radius.circular(radius))
                      : BorderRadius.only(bottomRight: Radius.circular(radius)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label.icon case final icon?) ...[
                        Icon(icon, size: 15, color: label.foreground),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label.text,
                        style: Fonts.sans(
                          13,
                          weight: 600,
                          color: label.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a corner of a recipe's photo says about where the recipe is.
final class PhotoLabel {
  const PhotoLabel.cooking()
    : text = 'Cooking now',
      icon = null,
      background = Palette.saffron,
      foreground = Palette.ink;

  PhotoLabel.toBuy(int toBuy)
    : text = toBuy == 0 ? 'All ticked' : '$toBuy to buy',
      icon = Icons.shopping_basket,
      background = Palette.cobalt,
      foreground = Palette.plate;

  final String text;
  final IconData? icon;
  final Color background;
  final Color foreground;

  /// The label for a planned recipe, if its stage needs one.
  static PhotoLabel? of(PlannedRecipe? entry, {int? toBuy}) =>
      switch (entry?.stage) {
        PlannedStage.cooking => const PhotoLabel.cooking(),
        PlannedStage.onList => PhotoLabel.toBuy(toBuy ?? 0),
        PlannedStage.toCook || null => null,
      };
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(color: Palette.hairline),
    child: Center(
      child: Icon(Icons.restaurant, size: 32, color: Palette.pewter),
    ),
  );
}

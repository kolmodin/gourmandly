# Design

The look of the app, so that later screens stay in step with it.

## Concept: square photos, as on the recipe sites

A recipe is its photo: square, with slightly rounded corners (6 pixels), the
title and time beneath it. This follows the Swedish recipe sites people already
use (ICA, Köket, Arla, Recepten.se), and the photos are the one bold element;
everything around them stays quiet. A recipe without a photo is a grey tile
with a cutlery icon.

A label in the corner of the photo says where a planned recipe is, as those
sites mark "popular" or "new":

| Label | Means |
|---|---|
| Saffron, "Cooking now" | Being cooked right now |
| Cobalt, basket and "3 to buy" | Planned, still on the shopping list |
| None | Shopped for, or not planned |

On the home screen, recipes still being shopped for are listed in their own
"Still shopping" section below "To cook", naming what is missing ("Missing:
guanciale, äggulor, pecorino"). A tap opens a sheet with those ingredients
to tick, so nobody has to find the recipe on the shopping list.

Saffron means cooking and nothing else, so selected states and accents are
cobalt.

## Colour

Swedish enamelware: a cool white rather than a warm cream, with the food photos
as the source of warmth.

| Token | Value | Use |
|---|---|---|
| Enamel | `#F4F7F6` | Background |
| Plate | `#FFFFFF` | Fields |
| Cobalt | `#1C3FAA` | Primary actions, ticks, the still-shopping label |
| Cobalt tint | `#E3E8F6` | The still-shopping box on a recipe |
| Ink | `#141E33` | Text |
| Pewter | `#5B6679` | Secondary text |
| Hairline | `#DCE2E5` | Dividers, field borders |
| Saffron | `#E8A317` | The cooking label |
| Saffron ink | `#7A5200` | Text next to it, which needs more contrast |

## Type

- **Young Serif** for titles: recipes, screens, sections.
- **Familjen Grotesk** for everything else.

Both are bundled in `app/assets/fonts/` (SIL Open Font License), so they work
offline in the shop.

## Layout

- Content is left-aligned. No all-caps labels, and no decoration that doesn't
  carry information.
- Numbers mark only what is a sequence: the steps of a recipe.
- Ticks are round.
- Below 840 pixels: one column and a bottom bar, and the recipe view opens with
  its photo edge to edge. From there on: a side rail, and in the recipe view a
  low header (a square photo beside the title) above two independently
  scrolling columns, so that the whole ingredient list and all steps are in
  view while cooking.

## Reviewing the design

`nix run .#screenshots` walks through the seeded app at phone and tablet sizes
and saves screenshots to `app/build/screenshots/`.

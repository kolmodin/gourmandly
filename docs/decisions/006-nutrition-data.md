# 006 — Nutrition data: Livsmedelsverket (USDA fallback), matched by AI

Status: accepted (2026-10-31). Applies when nutrition per serving is built
(on the wishlist).

## Context

Showing calories and macros per serving needs nutrition values for every
ingredient. AI recalls such numbers unreliably and can invent plausible ones,
but it is good at matching an ingredient description to an entry in a list.
Most imported recipes are Swedish.

## Options considered

- **Livsmedelsverket's food database** (Livsmedelsdatabasen): the Swedish Food
  Agency's open data, with Swedish food names that match Swedish recipes.
- **USDA FoodData Central**: public domain and larger, but American foods and
  English names.
- **AI for the values**: no data to maintain, but numbers can't be trusted.

## Decision

Nutrition values come from **Livsmedelsverket's food database**, with **USDA
FoodData Central as a fallback**. **AI does the matching** from ingredient to
database entry.

- Copies of both databases are kept in the backend and refreshed
  occasionally, rather than queried live on each import.
- At import, AI maps each ingredient key to a food in Livsmedelsverket's
  database (`red onion` → "Lök, röd, rå"). Only if there is no good match
  there does it try USDA FoodData Central (e.g. for ingredients uncommon in
  Sweden). The match is stored on the ingredient as source plus food ID, and
  users can correct it when editing an ingredient.
- Start with Livsmedelsverket alone and add the USDA fallback if unmatched
  ingredients turn out to be common.
- Values are computed from the database per 100 g, so amounts are converted to
  grams first (volume-to-mass densities and typical weights per piece, both on
  the wishlist).
- Nutrition stated by the recipe page itself (JSON-LD `NutritionInformation`)
  is used as a check, not as the source.
- The app credits Livsmedelsverket as the source, as its licence requires
  (check the current terms when building this). USDA data is public domain;
  crediting it too is good practice.

### Storing and computing

The inputs are stored per ingredient; totals are computed when displayed and
never stored (as everywhere in the [data model](../data-model.md): store what
people did, compute the rest). Stored totals would go stale whenever a
quantity, an ingredient, a match or a conversion is edited.

```
Ingredient
  + nutrition (optional)
      source        livsmedelsverket | usda
      foodId        the matched database entry
      per100g       { kcal, carbs, fat, protein }   copied at match time
      gramsPer      grams per ml (volumes) or per st (pieces);
                    not needed for g and kg
```

- Grams are derived from the ingredient's quantity and unit, so editing a
  quantity updates the macros without any recalculation step.
- `per100g` is a copy taken when the ingredient is matched, so the device
  computes offline without the database, and values don't shift when the
  database copy is refreshed. A new match (at import or when the user corrects
  it) fetches new values through the matching Function.
- Per serving = sum over ingredients ÷ the recipe's `servings`. It doesn't
  change when the recipe is scaled; the total does.
- Ingredients without a match are listed ("2 ingredients not included"), so a
  partial total is never presented as complete.
- The public share page computes the same sum on the server.

## Consequences

- One more optional field on ingredients (`nutrition`), per
  [003](003-data-evolution.md).
- Ingredients without a good match are left unmatched and shown as such, so a
  partial total is visible rather than silently wrong.

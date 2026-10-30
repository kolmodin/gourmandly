# Data model

Firestore, see [decisions/001-backend.md](decisions/001-backend.md). Every
change to this model follows
[decisions/003-data-evolution.md](decisions/003-data-evolution.md): additive
only, field-level updates, tolerant of missing and unknown fields.

## Principles

- **Everything belongs to a kitchen.** Access rule: you can read and write
  what's under `kitchens/{k}` if you are in `kitchens/{k}.memberIds`, with
  three exceptions: only the import Function writes import results and usage,
  and only the membership Functions change who belongs to a kitchen.
- **The whole kitchen syncs to every device.** A kitchen's data is small
  (hundreds of recipes, dozens of list records), so there are no server-side
  queries; search, aggregation and filtering run on the device.
- **Store what people did, compute the rest.** The shopping list stores
  records like "recipe X added at 8 servings" and "onion checked". Merged views
  and the export are computed on the device and never stored, so there's
  nothing derived to conflict.
- **One document per action**, usually written by one person. Concurrent
  edits rarely touch the same document; when they do, last write wins per
  field.
- **IDs are generated on the device**, so new documents can be created offline.
- **A write to something another member just removed does nothing.** It doesn't
  hold back the rest of the decision (see Writing).

## Collections

```
users/{uid}
kitchens/{k}
kitchens/{k}/recipes/{recipeId}
kitchens/{k}/tags/{tagId}
kitchens/{k}/staples/{keySlug}
kitchens/{k}/importJobs/{jobId}
kitchens/{k}/plannedRecipes/{entryId}
kitchens/{k}/listItems/{itemId}
kitchens/{k}/checks/{checkId}
kitchens/{k}/overrides/{keySlug}
kitchens/{k}/usage/{yyyy-mm-dd}
invites/{token}
shares/{shareId}
meta/app
```

### Users and kitchens

```
users/{uid}
  name, email, kitchenIds: [k]

kitchens/{k}
  name, ownerId, memberIds: [uid], createdAt
  memberNames       { uid: name }  so that members can see each other without
                    being able to read each other's accounts
  language          "sv", …  the language you shop in; defaults to the
                    creator's browser or device language

invites/{token}                     top level: the invitee isn't a member yet
  kitchenId, createdBy, expiresAt
```

Kitchens are created explicitly: a new user has none until they create one
or accept an invite. A user can belong to several; `kitchenIds` lists them,
and the device remembers which one is current. Every kitchen the user
belongs to is synced to the device.

Membership changes go through Cloud Functions; clients can't edit `ownerId`,
`memberIds`, `memberNames` or `kitchenIds` directly. Members can rename a
kitchen and change its language.

- **Create kitchen:** creates it with the default tags and staples. A user can
  have at most 10 kitchens.
- **Create invite:** any member can. The token is random, valid for 7 days, and
  works for several people until then.
- **Accept invite:** checks the token, adds the user to the kitchen.
- **Leave:** removes a member. When the owner leaves, the kitchen and
  everything under it (including stored photos and open invites) are deleted;
  the warning before that is up to the app. A deletion that is interrupted can
  be repeated by leaving again, and leaving a kitchen that is already gone just
  removes it from the user.
- **Transfer ownership:** the owner makes another member the owner.
- **Delete account:** leaves every kitchen as above, then deletes the user.

### Recipes

```
recipes/{recipeId}
  title
  language          "sv", "en", …  the kitchen's language at import
  original          optional, only when the source was in another language:
                    { language, title, ingredients, steps }   as imported, read-only
  sourceUrl
  image             { storagePath, sourceUrl, origin: page | ai }   optional
  servings          int
  totalTime         minutes, optional
  steps             [text]
  ingredients       [Ingredient]
  tagIds            [tagId]          edited with arrayUnion / arrayRemove
  importMethod      jsonld | ai | manual
  copiedFrom        shareId, optional
  lastCookedAt, timesCooked         see Planned recipes
  createdBy, createdAt, updatedAt

Ingredient
  id                stable, so edits and list exclusions survive
  text              "2 krm nymald svartpeppar"   as written
  name              "svartpeppar"                shown on the list and in the export
  key               "black pepper"               internal, for matching only
  quantity          { num, den }                 exact fraction
                  | { min: {num, den}, max: {num, den} }
                  | null                         "salt efter smak"
  unit              g | kg | ml | cl | dl | l | krm | tsk | msk | st
                  | any other unit by name: klyftor, burk, förp
                  | null                         a quantity without a unit counts pieces
  note              "gärna ekologisk", optional
  group             "Sås", optional section heading
```

The source language is detected from JSON-LD `inLanguage`, the page's `lang`
attribute, or AI. If it differs from the kitchen's language, the import
translates the recipe and stores the untranslated version in `original`. The
translation keeps the same ingredient IDs, quantities and units as the
original, so the cooking view scales both the same way. Edits go to the
translated version only; `original` is never changed, and nothing is ever
re-translated automatically, so edits can't be overwritten. Shares carry
`original` too, so a recipient with a third language translates from the
source rather than from a translation.

Quantities are fractions so scaling is exact (⅓ × 2 = ⅔). Units are metric,
including the Swedish volume units. Each unit has a dimension (mass, volume,
count) and an exact factor within it (krm = 1 ml, tsk = 5 ml, msk = 15 ml,
dl = 100 ml, kg = 1000 g). Quantities of the same key merge within a
dimension: "2 dl grädde" and "100 ml grädde" become "3 dl grädde", shown in
the largest unit that keeps the number readable. Mass and volume are never
converted into each other (see the wishlist).

Any other unit (`klyftor`, `burk`, `förp`) is a named unit: a measure of its
own, which merges only with itself. An ingredient without a quantity ("salt
efter smak") gets a line of its own, separate from quantified lines of the same
key.

The shown unit is the largest of the contributing units, `kg`, `l` and `dl`
that gives a readable number of at least one; otherwise the smallest
contributing unit that reads well ("½ dl"); otherwise the base unit. A number
is readable if it is measurable in a kitchen (halves, thirds, quarters, fifths,
sixths, eighths) and isn't more than 20 spoons. So 1500 g shows as "1 ½ kg",
1100 g stays "1100 g", and 1 l plus 1 tsk shows as "1005 ml".

### Ingredient keys

The `key` names the thing you buy, in English, regardless of the recipe's
language. It drives merging and the staples filter.

- Preparation that doesn't matter in the shop is dropped (`chopped onion` →
  `onion`). The kind of ingredient is kept exactly as the recipe states it:
  `onion` and `red onion` are different keys, and so are `onion` and `yellow
  onion`. The key never guesses a kind the recipe didn't state.
- Only identical keys merge. Different kinds of the same thing are separate
  lines on the shopping list, and the shopper decides what to buy.
- The import prompt includes the kitchen's existing keys and asks the AI to
  reuse them, **staples first**: a mismatch with a staple is the most visible
  failure (a staple that isn't filtered out), so staples are the highest
  priority vocabulary.
- Users can correct a key when editing an ingredient. Later: per-kitchen
  aliases (`ground black pepper` → `black pepper`).

### Tags

```
tags/{tagId}
  name              "quick"
  category          cuisine | diet | effort | meal | meatFish | other
  key               "effort.quick", only on seeded tags; survives renames
  createdAt
```

Recipes reference tags by ID, so renaming is one write and merging is a
small batch. Unknown tag IDs on a recipe are ignored and dropped on next save.
A tag with an unknown `category` value (written by a newer client) is shown
under Other.

The categories are fixed and defined in the app, not stored. The import
assigns zero or more tags in each category, choosing from existing tags; see
[brief.md](brief.md) for the defaults. User-defined categories are on the
wishlist; see [decisions/003-data-evolution.md](decisions/003-data-evolution.md)
for how they'd be added.

### Staples

```
staples/{keySlug}
  key               "black pepper"
  addedBy, addedAt
```

The document ID is derived from the key, so the same staple can't be added
twice. Seeded with defaults when the kitchen is created.

### Import jobs

```
importJobs/{jobId}
  url, status (pending | done | failed), error, recipeId
  createdBy, createdAt
```

The client creates the job; a Cloud Function fetches the page, extracts the
recipe (JSON-LD first, AI as fallback), assigns ingredient keys and tags,
writes the recipe, and updates the job. The app watches the job.

The photo comes from the page's metadata (`og:image`, JSON-LD `image`), or
else from AI picking the best image on the page. It is downloaded, resized
and stored in Cloud Storage under `kitchens/{k}/recipes/{recipeId}/`, with
the original URL kept in `image.sourceUrl`. If the page has no usable image,
the recipe has no `image`, and the app offers to generate one, which is a
separate, user-initiated call. Storage rules give kitchen members read
access.

### Planned recipes

A planned recipe is a recipe the kitchen intends to cook, at a given number
of servings. It moves through these stages:

```
add to list ──► on the shopping list ──► to cook ──► cooking ──► cooked
                (shoppedAt unset)        (shoppedAt  (cooking-    (entry deleted;
                                          set)        StartedAt    recipe records
                                                      set)         lastCookedAt)
```

```
plannedRecipes/{entryId}
  recipeId, servings, addedBy, addedAt
  excluded: [ingredientId]          "already have the cream for this one"
  done:     [ingredientId]          bought and cleared
  shoppedAt                         unset: on the shopping list; set: off it
  cookingStartedAt                  set when cooking starts
```

`timesCooked` on the recipe is updated with `increment`, so that two different
entries finishing at once both count.

On the home screen, planned recipes on the shopping list are listed under
"Still shopping", showing how much is left to buy; shopped ones are under "To
cook". Ways a planned recipe becomes **shopped** (leaves the shopping list,
moves to "To cook"):

- **Automatically**, when all its ingredients are done, excluded or staples
  (see Checking and clearing).
- **"Done shopping"** on the shopping list. If anything is still unchecked it
  asks: *everything is bought* (all planned recipes become shopped; manual
  items, checks and overrides are deleted), or *keep unchecked items* (only
  checked lines are cleared, as with "Clear checked").
- **"Already bought"** on one recipe, on its page or in the by-recipe view.
  Undo clears `shoppedAt` again.

**Starting to cook** (an explicit "Start cooking" button in the recipe view,
so merely looking at a recipe changes nothing):

- The servings can be adjusted first; for a planned recipe, the new servings
  are saved on the entry.
- **If the recipe is still on the shopping list**, its remaining ingredients
  are ticked off: their IDs are added to `done` and `shoppedAt` is set. Only
  this recipe's share of a merged line goes away; another recipe needing the
  same onions keeps its share. A snackbar offers undo, which removes the added
  IDs again with `arrayRemove`, clears both times, and restores the servings.
- **If the recipe isn't planned** (shopped without the app, or everything was
  already at home), starting to cook creates a planned entry with `shoppedAt`
  and `cookingStartedAt` set, at the chosen servings. It never touches the
  shopping list.
- `cookingStartedAt` is set, so the recipe shows as "Cooking" under "To cook"
  and can be reopened if the cook leaves the screen. Reopening only changes the
  servings, if they were adjusted.
- A recipe planned twice continues from the entry furthest along.

**Done cooking** (button at the end of the cooking view) deletes the entry and
updates `lastCookedAt` and `timesCooked` on the recipe, as one atomic step: if
two clients finish the same entry, it counts once, and if the recipe is gone,
the entry is still deleted. An entry whose cooking started more than 24 hours
ago is finished the same way by whichever client sees it first, recording the
time cooking started, so forgotten sessions don't pile up.

Shopped recipes that are never cooked stay under "To cook" until removed.

Ticks in the cooking view are kept on the device only, keyed by entry ID.

### Shopping list

One shopping list per kitchen. Items that are never bought, or bought
elsewhere, simply stay on it until checked or removed.

```
listItems/{itemId}                  manual items
  name, key (optional), quantity, unit, addedBy, addedAt

checks/{checkId}                    ID derived from key + unit dimension
  key               item:{itemId} for a manual item without a key
  dimension         mass | volume | count | none | named:{unit}
  checkedQuantity   { num, den } in the base unit (g, ml or st); the upper end
                    of a range;
                    unset for a line without a quantity
  checkedBy, checkedAt

overrides/{keySlug}
  key
  include           true: "add salt this time"; false: hide something that
                    isn't a staple. Wins over the staples list.
```

The ingredients view, the by-recipe view and the export are computed from
these records plus the planned recipes and recipes:

1. Take the planned recipes still on the shopping list (`shoppedAt` unset);
   scale their ingredients to their servings; drop excluded and done ones.
2. Hide staples unless overridden; show them collapsed under "probably at
   home".
3. Merge by key and unit dimension, converting between units of the same
   dimension; add manual items.
4. Compare with checks: if 3 onions were checked and the total is now 5, show
   "2 more".
5. Sort: open lines alphabetically, ignoring case and accents; fully checked
   lines at the bottom, most recently checked first.

Planned recipes reference the live recipe, so edits to a recipe show up on
the list. This needs no extra logic: ingredient IDs are stable, so `excluded`,
`done` and checks survive the edit, and a changed quantity shows up as "N
more" through step 4. If a recipe is deleted, its planned entries are deleted
in the same batch.

A manual item gets a key when it can (from a local match against existing
keys, or from a Function when online); until then it isn't merged.

#### Merged wording

Recipes are stored in the kitchen's language, so contributions to a merged
line normally share a language; the line shows the wording of the earliest
added contribution. (Recipes imported before a change of kitchen language
are the exception, and get the same rule.) Tapping the line shows every
source.

#### Export

One line per open line of the ingredients view, as quantity, unit and name ("5
st gul lök"); a line without a quantity is just the name, and a partly checked
line gives what is left to buy. Staples hidden by the filter and fully checked
lines are left out.

#### Checking and clearing

- Checking a line writes a check record; unchecking deletes it. Lines move to
  the bottom when checked, like Google Keep.
- Checked lines stay visible, collapsed under "Checked (n)", until cleared.
- **Clear checked** (a button) removes every fully checked line: manual items
  are deleted, recipe ingredients are added to their entry's `done` (with
  `arrayUnion`), and the check record is deleted, along with the override if
  there is one to delete (see below). Partly checked lines ("2 more") are left
  alone.
- A planned recipe whose ingredients are all done, excluded or staples gets
  `shoppedAt` set in the same batch, taking it off the list. That includes a
  recipe with nothing to buy in the first place.
- Checks whose line no longer exists (the recipe was removed, or the key became
  a staple) are deleted in the same batch, so that they can't tick the line
  when it comes back, but only when the data is known to be complete: offline, a
  partial cache could be missing the recipes behind a check. Automatic clearing
  runs only once the kitchen is in sync, and only deletes such checks when they
  are old as well.
- An override is deleted with its line only if it brought a staple back and no
  other line of that key is left.
- **Automatic clearing:** lines checked more than 24 hours ago are cleared the
  same way by whichever client opens the list first. This covers the usual
  case (shopping is done, nobody pressed the button) while keeping a whole
  shopping trip visible for unchecking mistakes. Two clients clearing at once is
  harmless: deleting twice, adding to a set twice and setting the same time
  twice all end up the same. A device with a clock far ahead clears early, which
  is accepted: times are device times, as ticks have to work offline.

### Shares (follow-up, after v1)

```
shares/{shareId}                    random, unguessable
  kitchenId, sharedBy, sharedByName (optional)
  snapshot { title, language, original, image, servings, ingredients, steps,
             sourceUrl, tagNames }
  createdAt, revokedAt
```

Anyone can read a single share by ID; nobody can list them. Adding a shared
recipe copies it into the recipient's kitchen, matching tag names against
their tags.

### App metadata

```
meta/app
  minSupportedVersion
  importsEnabled    kill switch for the import Function
```

### Usage

```
kitchens/{k}/usage/{yyyy-mm-dd}   written by the import Function only
  imports, aiInputTokens, aiOutputTokens
```

One document per day: today's holds the per-kitchen import quota, and all of
them together show what a kitchen has used, for spotting abuse (see
[decisions/001-backend.md](decisions/001-backend.md)). Members can read it; only
the Function writes it.

## Writing

The functions in `packages/domain` return *effects*, and the repository layer
applies the effects of one decision together:

- Sets and deletes go in one batch. They can't fail on a missing document.
- Updates of planned recipes go separately. An update requires its document to
  exist, and in a batch, one document that another member just removed would
  take everything else down with it. A rejected update of a missing document is
  ignored.
- Existing documents only get field-level writes, see
  [decisions/003-data-evolution.md](decisions/003-data-evolution.md).
  Editing a recipe's ingredients will have to rewrite the whole array, which
  needs care with fields a client doesn't know.

## Later

- Nicknames: an optional `nickname` on `users/{uid}`, shown instead of the
  Google name. Documents store user IDs (`addedBy`, `checkedBy`, …), not
  names, so a changed nickname shows up everywhere at once: it is copied into
  `memberNames` on the user's kitchens. Shares copy the name at share time
  (`sharedByName`).
- Several shopping lists per kitchen would add a `listId` to the list
  records.
- Moving or copying recipes between kitchens: a copy into the other
  kitchen, the same operation as adding a shared recipe.

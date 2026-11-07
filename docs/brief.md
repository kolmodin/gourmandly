# Gourmandly — product brief

## Problem

Recipes live scattered across websites. Turning "what we'll cook this week" into
a shopping list means re-reading each recipe, scaling quantities by hand,
merging duplicates, and skipping things already in the pantry.

## Who it's for

A household (initially: the author's family) where two or more adults share
cooking and grocery shopping. Small scale; it may never have users beyond that.

## What it does

### Recipe store
- Add a recipe by pasting a link. On Android, the installed web app can also
  appear in the share sheet ("Share → Gourmandly") through the Web Share
  Target API.
- The recipe is extracted server-side: structured data (schema.org `Recipe`
  JSON-LD) first, AI as fallback. Extracted: title, ingredients, steps,
  servings, total time, language and source URL. The import also assigns
  ingredient keys and tags, and translates the recipe if needed (see
  Language).
- A representative photo is taken from the page: from its metadata
  (`og:image`, JSON-LD `image`) if present, otherwise AI picks the best image
  on the page. Only if the page has no usable image does the app offer to
  generate one with AI. The photo is copied into the app's storage, so it
  survives the source site changing or disappearing.
- Recipes can be edited after import (extraction will sometimes be wrong).
- Recipes have tags (italian, asian, vegetarian, quick, ambitious, …). Tags
  are applied automatically at import and can be edited later. Each kitchen
  has its own tag list, seeded with defaults, where tags can be renamed,
  merged and deleted.
- Every tag belongs to one of a fixed set of **categories**. The import
  assigns the tags that apply in each category, zero or more, choosing from
  the kitchen's existing tags where possible:

  | Category | Default tags |
  |---|---|
  | Cuisine | asian, chinese, japanese, korean, thai, vietnamese, indian, middle eastern, mediterranean, italian, french, spanish, greek, nordic, american, mexican |
  | Diet | vegetarian, vegan, pescetarian, gluten-free, dairy-free |
  | Effort | quick (≤ 30 min), everyday, ambitious |
  | Meal | breakfast, lunch, dinner, starter, side, dessert, baking, snack, drink |
  | Meat & fish | chicken, pork, beef, lamb, game, fish, seafood |
  | Other | (none by default; for tags like "grill" or "christmas") |

- "vegetarian" is judged from the whole ingredient list, so a soup with
  chicken stock isn't vegetarian even without a Meat & fish tag.
- Users can create tags and move them between categories, but the categories
  themselves are fixed. A new tag the AI suggests goes into the category it
  was suggested for.
- Seeded tags carry a stable `key` (e.g. `effort.quick`) so the app can find
  them even if renamed (the import sets "quick" from the total time).
- Recipes are searchable by title, ingredient and tag. Tag filters are
  grouped by category:
  - within a category, any selected tag matches ("chicken or pork");
  - across categories, all must match ("… and quick and asian");
  - a category can also be filtered to **none** ("no meat or fish").

  Search runs on the device over the kitchen's synced recipes.

### From shopping to cooking
- Recipes added to the shopping list are *planned*. Once shopped, they leave
  the shopping list and appear under **"To cook"** on the home screen, as
  photo cards. Until then they are listed under **"Still shopping"** just
  below, naming the ingredients still missing. Tapping one shows them over
  the home screen, to tick off there (the shopping list's own ticks), mark
  the recipe as already bought, or open it.
- A recipe counts as shopped when all its items are ticked off and cleared,
  when "Done shopping" is pressed on the list (which asks whether unticked
  items were bought too, e.g. after ordering through Willys), or when it's
  marked as **Already bought** on its own, from its page or from the list's
  by-recipe view (with undo).
- A recipe still on the shopping list says so on its page, with buttons to
  see what's missing (the by-recipe view, at that recipe) and to mark it as
  already bought. The by-recipe view ends with the recipes already bought,
  so the two screens never disagree silently.
- **Start cooking** is a button on any recipe. The servings can be adjusted
  first. If the recipe is still on the shopping list, its items are ticked
  off (only its own share of merged lines, with undo). If it isn't planned at
  all (shopped without the app), cooking simply starts.
- **Done cooking** removes it from "To cook" and records when it was last
  cooked and how many times.

### Cooking view
- Shows a recipe for cooking: ingredients and all steps at once, scaled to the
  chosen servings (defaulting to the planned servings, if the recipe is
  planned).
- Ingredients and steps can be ticked off while cooking. Ticks are kept on the
  device only, not synced.
- Keeps the screen on while open.
- Uses the recipe's photo as part of the view (e.g. a header image).
- For translated recipes, a button switches between the kitchen language
  and the original language.
- Layout adapts to the screen:
  - **Phone:** one column, ingredients followed by steps.
  - **Tablet** (and wide web windows): two columns side by side, the whole
    ingredient list on one side and the steps on the other, scrolling
    independently.

### Shopping list
- Pick recipes from the store, scale them (e.g. 4 → 8 servings), add to the list.
- Two views:
  - **Ingredients:** all items flattened and aggregated.
  - **By recipe:** grouped per recipe, so a whole recipe can be removed, or
    an ingredient left out because it's already at home. Both can be undone,
    and left-out ingredients stay listed under the recipe to bring back.
- Manual items (e.g. "milk") can be added without a recipe.
- Check items off while shopping. Works offline and syncs live between
  kitchen members, similar to Google Keep.
- **Export:** copy the unchecked items, one per line, for pasting into store
  importers (e.g. Willys).
- Quantities are metric only; scaled quantities shown as fractions.

### Pantry filter
- Each kitchen has an editable staples list (water, salt, pepper, …),
  seeded with sensible defaults.
- Matching ingredients aren't dropped; they're collapsed under "probably at
  home" with one-tap re-add.

### Kitchens
- A **kitchen** is what the app calls a recipe store plus a shopping list,
  shared by the people who cook together (typically a household). They are
  not shared separately.
- Kitchens are created explicitly. After signing in for the first time, a
  dialog offers to **create a new recipe bank and shopping list** or **join an
  existing one** (through an invite link), so nobody starts importing into an
  accidental kitchen.
- A user can belong to several kitchens and switches between them; the
  current one is remembered per device.
- Members can invite others with a link that works for a week. All members can
  read and write the kitchen's recipe store and shopping list.
- Each kitchen has one **owner**, initially its creator. Other members can
  leave at any time. The owner can hand ownership to another member; when the
  owner leaves without doing so, the kitchen and all its data are deleted
  (after a warning).
- Sign in with Google.
- Users can delete their account and data, from the app and from the web.
  Deleting an account leaves every kitchen, with the same rules as above.

### Recipe sharing (follow-up, after v1)
- Share a single recipe as a link, e.g. through the system share sheet.
- The link serves two purposes:
  - **Reading:** anyone can open it and cook from it, without an account. The
    page looks like the cooking view: the photo, ingredients and steps (two
    columns on wide screens), adjustable servings, and the screen kept on.
  - **Importing:** a button adds the recipe to your own kitchen, as an
    independent copy. Without an account, the buttons are **Sign in** and
    **Create account** (Google sign-in followed by creating a kitchen), after
    which the recipe is added.
- The page is rendered on the server rather than by the Flutter app, so it
  loads instantly and messaging apps show a preview with title and photo.
- Once the Android app exists, the link opens it directly (App Links).
- Shares are snapshots taken when shared, can be revoked, and are only
  reachable through their unguessable link.

## Platforms

v1 is the web app, usable on phones, tablets and computers, and installable
as a progressive web app. The Android app is first on the wishlist; a native
macOS app is also on it. There is no plan for an iOS app.

Hosted at `gourmandly.kolmodin.com`: the web app at `/`, public shared recipes
at `/r/{shareId}`, and later App Links verification for the Android app at
`/.well-known/`. The dev environment is at `dev.gourmandly.kolmodin.com`. The
domain is build-time configuration so others can run their own instance.

## Language

The app's own text, tags and the default staples list are in English.

Each kitchen has a language: the language it shops in. A recipe in another
language is translated into it at import, and the original is kept alongside.
The cooking view can switch between the two. The kitchen-language version is
the one that is edited and used for the shopping list and the export; the
original is a read-only reference as imported.

Each ingredient also gets an English canonical key at import, used for
merging duplicates and for the staples filter, so "svartpeppar" still matches
the staple "black pepper".

## Principles

- Open source, no ads, no monetization.
- Visually appealing. Recipe photos are a central part of the look, including
  in the cooking view. The design is iterated on with previews and screenshots.
- Good enough for one family beats feature-complete.
- Testable end-to-end, including against a local backend.

Backend: Firebase, see [decisions/001-backend.md](decisions/001-backend.md).
Data model: [data-model.md](data-model.md).

## Non-goals (for now)

- Meal planning / calendar
- A public recipe feed or other social features (sharing one recipe by link
  is on the wishlist)
- Importing from photos of cookbooks
- Grocery delivery integration
- Imperial units

## Wishlist (later)

- **Android app** (first on the list): minSdk 33, see
  [decisions/002-android-min-sdk.md](decisions/002-android-min-sdk.md);
  distributed through GitHub Releases, see
  [decisions/005-distribution.md](decisions/005-distribution.md). Includes
  the native share sheet, and App Links for shared recipes.
- Recipe sharing (see Recipe sharing above).
- Timers in the cooking view, started from steps that mention a time
  ("simmer for 20 minutes").
- Nicknames: users pick a nickname when they sign up, and can change it later
  on a Profile page. It's shown wherever the app names people (who added or
  checked an item, kitchen members, shared recipes). Until then, and for
  users who skip it, the first name from the Google profile is used.
- User-defined tag categories (creating, renaming and reordering categories).
- Ingredient key aliases per kitchen.
- Push notifications (e.g. "an item was added to the list").
- Moving or copying recipes from one kitchen to another.
- Replacing a recipe's photo with your own, from the camera or Google Photos.
- Several shopping lists per kitchen.
- Volume-to-mass conversion for ingredients where it's well defined, shown in
  parentheses in the ingredient list: "3 dl vetemjöl (180 g)". Needs a density
  per ingredient key (flour ≈ 60 g/dl). Merging mass and volume on the
  shopping list can follow if mixed units turn out to be common.
- Nutrition per serving: calories and macros (carbohydrates, fat, protein)
  shown with the recipe, following the chosen servings.
  - Values come from Livsmedelsverket's food database, with USDA FoodData
    Central as a fallback, and AI matches each ingredient to an entry (`red
    onion` → "Lök, röd, rå"). The match is
    stored on the ingredient and can be corrected by the user. See
    [decisions/006-nutrition-data.md](decisions/006-nutrition-data.md).
  - Amounts must be converted to grams first, so this builds on the
    volume-to-mass item above, plus a typical weight per piece ("1 st lök ≈
    150 g").
  - When the recipe page already includes nutrition (JSON-LD
    `NutritionInformation`), it can be shown directly or used as a check.
- Native macOS app (needs Xcode, and the Apple Developer Program to sign and
  notarize builds distributed outside the App Store). Until then, the web app
  covers the Mac (installable via Safari's "Add to Dock" or Chrome's "Install
  app").
- Built-in auto-update on Android: the app fetches new versions from GitHub
  Releases and installs them.
- Google Play distribution (with App Check via Play Integrity).

## Open questions

None besides the postponed ones.

### Postponed

- Default contents of the staples list and the tag list.
- Recipe sharing: how much of an imported recipe the public page may show
  (full method, or ingredients plus a link to the source)? Show the sharer's
  name?

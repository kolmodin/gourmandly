# 003 — Evolving the data format

Status: accepted (2026-10-30)

## Context

Clients read and write Firestore directly, so the stored documents are the
API (see [001](001-backend.md)). Older app versions keep running after a
release (web tabs left open, installed web apps serving a cached version, and
later Android installs that update late), so they keep reading and writing
data produced by newer ones, and the other way around. There is no server
layer to translate between versions.

The rules apply to the *format* of the data: field and collection names, types
and meanings. Values are ordinary data; renaming a tag, for example, only
changes its `name` and is always fine.

## Decision

1. **Changes are additive.** New fields and new collections only. Fields are
   never renamed, repurposed or changed in type; a replacement gets a new name
   and the old one is left in place until no supported client uses it.
2. **Missing fields have defaults.** Every field added after the first release
   is optional, and the client defines what its absence means.
3. **Unknown fields are ignored** when reading, never treated as errors.
4. **Clients never overwrite whole documents they didn't create.** Edits use
   `update()` with the changed fields only (or `set(..., merge: true)`), so an
   older client can't erase fields it doesn't know about. Array membership
   changes use `arrayUnion`/`arrayRemove`.
5. **New rules must tolerate old data.** Constraints that older clients can't
   know about (e.g. "pick at most one tag from this category") are hints in the
   UI, not invariants the code relies on.
6. **Deploy order:** Security Rules first, then Functions, then clients. Rules
   accept both the old and the new shape for as long as old clients are
   supported.
7. **Escape hatch for breaking changes:** a `meta/app` document holds
   `minSupportedVersion`. Clients below it show "please update" instead of
   writing data they no longer understand. Used rarely.

## Example: user-defined tag categories

In v1, tag categories are fixed: each tag in `kitchens/{k}/tags/{tagId}` has
a `category` from a set defined in the app (cuisine, diet, …), and recipes
hold `tagIds`. Letting users define their own categories later:

- New collection `kitchens/{k}/tagCategories/{categoryId}` with `name` and
  `order`, seeded with the fixed categories.
- New optional field `categoryId` on tags. A tag without one keeps using its
  `category`, which maps to the seeded entry. `category` stays in place, per
  rule 1.
- No recipe documents change, because recipes reference tags by ID.
- Old clients keep showing the fixed categories and keep working. Because
  they edit tags with field-level updates, they don't erase `categoryId`.

## Consequences

- Rule 4 is enforced in the repository layer of the app, and tested: an
  "old client" test writes with the previous model and checks that newer
  fields survive.
- Data model classes are written to tolerate missing and unknown fields from
  the start, including in v1.

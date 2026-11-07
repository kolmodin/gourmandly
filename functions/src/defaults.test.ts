import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { keySlug } from "./defaults.ts";

// The same cases as packages/domain/test/text_test.dart: the app and the
// Functions must agree.
describe("keySlug", () => {
  it("makes a key usable as a document ID", () => {
    assert.equal(keySlug("black pepper"), "black-pepper");
    assert.equal(keySlug("Black  Pepper"), "black-pepper");
    assert.equal(keySlug("salt/peppar"), "salt%2Fpeppar");
    assert.equal(keySlug("crème fraîche"), "crème-fraîche");
    assert.equal(keySlug("st. agur"), "st%2E-agur");
    assert.equal(keySlug("half-and-half"), "half%2Dand%2Dhalf");
  });

  it("never yields a reserved document ID", () => {
    assert.equal(keySlug("."), "%2E");
    assert.equal(keySlug(".."), "%2E%2E");
    assert.equal(keySlug("__id__"), "%5F%5Fid%5F%5F");
  });
});

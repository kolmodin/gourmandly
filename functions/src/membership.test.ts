import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  acceptance,
  canCreateKitchen,
  canInvite,
  inviteExpiry,
  leaving,
  memberName,
  parseId,
  parseKitchenName,
  parseLanguage,
  transfer,
} from "./membership.ts";
import type { Decision, Kitchen } from "./membership.ts";

const kitchen: Kitchen = { ownerId: "alice", memberIds: ["alice", "bob"] };
const now = new Date("2026-11-01T12:00:00Z");

function refusalCode<T>(decision: Decision<T>): string | undefined {
  return decision.ok ? undefined : decision.refusal.code;
}

describe("parseKitchenName", () => {
  it("trims a name", () => {
    assert.deepEqual(parseKitchenName("  Hemma "), { ok: true, value: "Hemma" });
  });

  for (const name of [undefined, 1, "", "   ", "x".repeat(81)]) {
    it(`refuses ${JSON.stringify(name)?.slice(0, 12)}`, () => {
      assert.equal(refusalCode(parseKitchenName(name)), "invalid-argument");
    });
  }
});

describe("parseLanguage", () => {
  it("keeps the language of a tag", () => {
    assert.equal(parseLanguage("sv"), "sv");
    assert.equal(parseLanguage("sv-SE"), "sv");
    assert.equal(parseLanguage("EN_gb"), "en");
  });

  it("falls back to English", () => {
    for (const language of [undefined, 1, "", "toolongcode", "s1"]) {
      assert.equal(parseLanguage(language), "en");
    }
  });
});

describe("parseId", () => {
  it("accepts an ID", () => {
    assert.deepEqual(parseId("k1", "kitchen"), { ok: true, value: "k1" });
  });

  it("refuses anything Firestore wouldn't take as a document ID", () => {
    for (const value of [undefined, 1, "", "k1/recipes", ".", "..", "__x__"]) {
      assert.equal(refusalCode(parseId(value, "kitchen")), "invalid-argument");
    }
  });
});

describe("canCreateKitchen", () => {
  it("allows up to ten kitchens", () => {
    assert.equal(canCreateKitchen(Array(9).fill("k")).ok, true);
    assert.equal(
      refusalCode(canCreateKitchen(Array(10).fill("k"))),
      "failed-precondition",
    );
  });
});

describe("memberName", () => {
  it("uses the name of the account", () => {
    assert.equal(memberName("Anna"), "Anna");
  });

  it("is empty without one", () => {
    assert.equal(memberName(undefined), "");
    assert.equal(memberName(1), "");
  });
});

describe("canInvite", () => {
  it("lets members invite", () => {
    assert.equal(canInvite(kitchen, "bob").ok, true);
  });

  it("doesn't reveal whether a kitchen exists to outsiders", () => {
    assert.equal(refusalCode(canInvite(kitchen, "mallory")), "not-found");
    assert.equal(refusalCode(canInvite(undefined, "mallory")), "not-found");
  });
});

describe("acceptance", () => {
  const invite = { kitchenId: "k1", expiresAt: inviteExpiry(now) };

  it("accepts a valid invite", () => {
    assert.deepEqual(acceptance(invite, kitchen, now), { ok: true, value: "k1" });
  });

  it("is valid for seven days", () => {
    assert.equal(invite.expiresAt.toISOString(), "2026-11-08T12:00:00.000Z");
    const almost = new Date(invite.expiresAt.getTime() - 1);
    assert.equal(acceptance(invite, kitchen, almost).ok, true);
    assert.equal(
      refusalCode(acceptance(invite, kitchen, invite.expiresAt)),
      "failed-precondition",
    );
  });

  it("refuses unknown invites and deleted kitchens", () => {
    assert.equal(refusalCode(acceptance(undefined, kitchen, now)), "not-found");
    assert.equal(refusalCode(acceptance(invite, undefined, now)), "not-found");
  });
});

describe("leaving", () => {
  it("removes a member", () => {
    assert.deepEqual(leaving(kitchen, "bob"), { ok: true, value: "removeMember" });
  });

  it("deletes the kitchen when the owner leaves", () => {
    assert.deepEqual(leaving(kitchen, "alice"), { ok: true, value: "deleteKitchen" });
  });

  it("refuses outsiders", () => {
    assert.equal(refusalCode(leaving(kitchen, "mallory")), "not-found");
  });

  it("forgets a kitchen that is gone", () => {
    assert.deepEqual(leaving(undefined, "alice"), { ok: true, value: "forget" });
  });
});

describe("transfer", () => {
  it("lets the owner hand over to a member", () => {
    assert.equal(transfer(kitchen, "alice", "bob").ok, true);
  });

  it("refuses anyone but the owner", () => {
    assert.equal(refusalCode(transfer(kitchen, "bob", "bob")), "permission-denied");
  });

  it("refuses a new owner who isn't a member", () => {
    assert.equal(
      refusalCode(transfer(kitchen, "alice", "mallory")),
      "failed-precondition",
    );
  });

  it("refuses outsiders without revealing the kitchen", () => {
    assert.equal(refusalCode(transfer(kitchen, "mallory", "bob")), "not-found");
    assert.equal(refusalCode(transfer(undefined, "alice", "bob")), "not-found");
  });
});

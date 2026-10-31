// The membership Functions, called over the real protocol against the
// emulators, as different signed-in users.
import assert from "node:assert/strict";
import { after, before, beforeEach, describe, it } from "node:test";

import { deleteApp, getApps, initializeApp } from "firebase-admin/app";
import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getAuth as adminAuth } from "firebase-admin/auth";
import { initializeApp as initializeClient } from "firebase/app";
import type { FirebaseApp } from "firebase/app";
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} from "firebase/auth";
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from "firebase/functions";

const projectId = "demo-gourmandly";
const bucket = `${projectId}.appspot.com`;

let appCount = 0;
const clients: FirebaseApp[] = [];

interface User {
  uid: string;
  call(name: string, data?: unknown): Promise<Record<string, string>>;
}

async function signedInUser(name: string): Promise<User> {
  const app = initializeClient(
    { apiKey: "demo", projectId, appId: "demo" },
    `client-${appCount++}`,
  );
  clients.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const functions = getFunctions(app, "europe-north1");
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  const { user } = await createUserWithEmailAndPassword(
    auth,
    `${name}-${appCount}@example.com`,
    "password",
  );
  return {
    uid: user.uid,
    call: async (fn, data) =>
      (await httpsCallable(functions, fn)(data)).data as Record<string, string>,
  };
}

function anonymous(): User["call"] {
  const app = initializeClient(
    { apiKey: "demo", projectId, appId: "demo" },
    `client-${appCount++}`,
  );
  clients.push(app);
  const functions = getFunctions(app, "europe-north1");
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  return async (fn, data) =>
    (await httpsCallable(functions, fn)(data)).data as Record<string, string>;
}

async function refused(call: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(call, (error: { code?: string }) => {
    assert.equal(error.code, `functions/${code}`);
    return true;
  });
}

const db = () => getFirestore();
const kitchen = async (id: string) => (await db().doc(`kitchens/${id}`).get()).data();
const kitchenIds = async (uid: string) =>
  (await db().doc(`users/${uid}`).get()).data()?.["kitchenIds"] as string[] | undefined;

let alice: User;
let bob: User;
let mallory: User;

async function clearEmulators(): Promise<void> {
  await fetch(
    `http://127.0.0.1:8080/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  await fetch(`http://127.0.0.1:9099/emulator/v1/projects/${projectId}/accounts`, {
    method: "DELETE",
  });
}

before(() => {
  initializeApp({ projectId, storageBucket: bucket });
});

after(async () => {
  await Promise.all(getApps().map(deleteApp));
  process.exit(0);
});

beforeEach(async () => {
  await clearEmulators();
  alice = await signedInUser("alice");
  bob = await signedInUser("bob");
  mallory = await signedInUser("mallory");
});

async function kitchenWithBob(): Promise<string> {
  const { kitchenId } = await alice.call("createKitchen", { name: "Hemma" });
  const { token } = await alice.call("createInvite", { kitchenId });
  await bob.call("acceptInvite", { token });
  return kitchenId as string;
}

describe("createKitchen", () => {
  it("creates a kitchen owned by the caller", async () => {
    const { kitchenId } = await alice.call("createKitchen", {
      name: " Hemma ",
      language: "sv-SE",
    });
    const created = await kitchen(kitchenId as string);
    assert.equal(created?.["name"], "Hemma");
    assert.equal(created?.["ownerId"], alice.uid);
    assert.deepEqual(created?.["memberIds"], [alice.uid]);
    assert.equal(created?.["language"], "sv");
    assert.deepEqual(await kitchenIds(alice.uid), [kitchenId]);
  });

  it("seeds the default tags and staples", async () => {
    const { kitchenId } = await alice.call("createKitchen", { name: "Hemma" });
    const tags = await db().collection(`kitchens/${kitchenId}/tags`).get();
    const staples = await db().collection(`kitchens/${kitchenId}/staples`).get();
    const quick = tags.docs.find((tag) => tag.data()["key"] === "effort.quick");
    assert.equal(quick?.data()["category"], "effort");
    assert.ok(tags.size > 30);
    assert.ok(staples.docs.some((staple) => staple.id === "black-pepper"));
  });

  it("a user can have several kitchens", async () => {
    const first = await alice.call("createKitchen", { name: "Hemma" });
    const second = await alice.call("createKitchen", { name: "Sommarstugan" });
    assert.deepEqual(await kitchenIds(alice.uid), [
      first["kitchenId"],
      second["kitchenId"],
    ]);
  });

  it("refuses a missing name and signed-out callers", async () => {
    await refused(alice.call("createKitchen", { name: "  " }), "invalid-argument");
    await refused(anonymous()("createKitchen", { name: "Hemma" }), "unauthenticated");
  });
});

describe("invites", () => {
  it("adds the invitee to the kitchen", async () => {
    const kitchenId = await kitchenWithBob();
    assert.deepEqual((await kitchen(kitchenId))?.["memberIds"], [alice.uid, bob.uid]);
    assert.deepEqual(await kitchenIds(bob.uid), [kitchenId]);
  });

  it("any member can invite", async () => {
    const kitchenId = await kitchenWithBob();
    const { token } = await bob.call("createInvite", { kitchenId });
    assert.ok(token);
  });

  it("an invite works for several people", async () => {
    const { kitchenId } = await alice.call("createKitchen", { name: "Hemma" });
    const { token } = await alice.call("createInvite", { kitchenId });
    await bob.call("acceptInvite", { token });
    await mallory.call("acceptInvite", { token });
    assert.equal(((await kitchen(kitchenId as string))?.["memberIds"] as string[]).length, 3);
  });

  it("accepting twice changes nothing", async () => {
    const { kitchenId } = await alice.call("createKitchen", { name: "Hemma" });
    const { token } = await alice.call("createInvite", { kitchenId });
    await bob.call("acceptInvite", { token });
    await bob.call("acceptInvite", { token });
    assert.equal(((await kitchen(kitchenId as string))?.["memberIds"] as string[]).length, 2);
  });

  it("outsiders can't invite", async () => {
    const kitchenId = await kitchenWithBob();
    await refused(mallory.call("createInvite", { kitchenId }), "not-found");
    await refused(mallory.call("createInvite", { kitchenId: "missing" }), "not-found");
  });

  it("refuses unknown and expired invites", async () => {
    await refused(bob.call("acceptInvite", { token: "guess" }), "not-found");
    const { kitchenId } = await alice.call("createKitchen", { name: "Hemma" });
    await db()
      .doc("invites/old")
      .create({ kitchenId, expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    await refused(bob.call("acceptInvite", { token: "old" }), "failed-precondition");
  });

  it("refuses an invite to a deleted kitchen", async () => {
    await db()
      .doc("invites/stale")
      .create({ kitchenId: "gone", expiresAt: Timestamp.fromMillis(Date.now() + 100000) });
    await refused(bob.call("acceptInvite", { token: "stale" }), "not-found");
  });
});

describe("leaveKitchen", () => {
  it("removes a member and keeps the kitchen", async () => {
    const kitchenId = await kitchenWithBob();
    await bob.call("leaveKitchen", { kitchenId });
    assert.deepEqual((await kitchen(kitchenId))?.["memberIds"], [alice.uid]);
    assert.deepEqual(await kitchenIds(bob.uid), []);
  });

  it("deletes the kitchen with everything in it when the owner leaves", async () => {
    const kitchenId = await kitchenWithBob();
    const path = `kitchens/${kitchenId}`;
    await db().doc(`${path}/recipes/r1`).set({ title: "Soppa" });
    const photo = `${path}/recipes/r1/photo.jpg`;
    await getStorage().bucket().file(photo).save("image");

    await alice.call("leaveKitchen", { kitchenId });

    assert.equal(await kitchen(kitchenId), undefined);
    assert.equal((await db().collection(`${path}/recipes`).get()).size, 0);
    assert.equal((await db().collection(`${path}/tags`).get()).size, 0);
    assert.deepEqual(await kitchenIds(alice.uid), []);
    assert.deepEqual(await kitchenIds(bob.uid), []);
    const [exists] = await getStorage().bucket().file(photo).exists();
    assert.equal(exists, false);
  });

  it("revokes open invites along with the kitchen", async () => {
    const { kitchenId } = await alice.call("createKitchen", { name: "Hemma" });
    const { token } = await alice.call("createInvite", { kitchenId });
    await alice.call("leaveKitchen", { kitchenId });
    await refused(bob.call("acceptInvite", { token }), "not-found");
  });

  it("outsiders can't remove anything", async () => {
    const kitchenId = await kitchenWithBob();
    await refused(mallory.call("leaveKitchen", { kitchenId }), "not-found");
    assert.equal(((await kitchen(kitchenId))?.["memberIds"] as string[]).length, 2);
  });
});

describe("transferOwnership", () => {
  it("makes a member the owner, who then keeps the kitchen alive", async () => {
    const kitchenId = await kitchenWithBob();
    await alice.call("transferOwnership", { kitchenId, newOwnerId: bob.uid });
    assert.equal((await kitchen(kitchenId))?.["ownerId"], bob.uid);

    await alice.call("leaveKitchen", { kitchenId });
    assert.deepEqual((await kitchen(kitchenId))?.["memberIds"], [bob.uid]);
  });

  it("only the owner can do it", async () => {
    const kitchenId = await kitchenWithBob();
    await refused(
      bob.call("transferOwnership", { kitchenId, newOwnerId: bob.uid }),
      "permission-denied",
    );
  });

  it("the new owner has to be a member", async () => {
    const kitchenId = await kitchenWithBob();
    await refused(
      alice.call("transferOwnership", { kitchenId, newOwnerId: mallory.uid }),
      "failed-precondition",
    );
  });
});

describe("deleteAccount", () => {
  it("leaves kitchens by the usual rules and removes the user", async () => {
    const shared = await kitchenWithBob();
    const { kitchenId: own } = await bob.call("createKitchen", { name: "Bobs" });

    await bob.call("deleteAccount");

    assert.deepEqual((await kitchen(shared))?.["memberIds"], [alice.uid]);
    assert.equal(await kitchen(own as string), undefined);
    assert.equal((await db().doc(`users/${bob.uid}`).get()).exists, false);
    await assert.rejects(adminAuth().getUser(bob.uid));
  });

  it("works for a user without kitchens", async () => {
    await mallory.call("deleteAccount");
    await assert.rejects(adminAuth().getUser(mallory.uid));
  });

  it("refuses signed-out callers", async () => {
    await refused(anonymous()("deleteAccount"), "unauthenticated");
  });
});

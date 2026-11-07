// Callable Functions for kitchens and membership. Clients can't change
// membership themselves; the rules leave that to these functions.
import "./options.ts";

import { randomBytes } from "node:crypto";

import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import type { DocumentReference, Firestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";

import { defaultStaples, defaultTags, keySlug } from "./defaults.ts";
import {
  acceptance,
  canCreateKitchen,
  canInvite,
  forgetting,
  inviteExpiry,
  leaving,
  memberName,
  parseId,
  parseKitchenName,
  parseLanguage,
  transfer,
} from "./membership.ts";
import type { Decision, Invite, Kitchen } from "./membership.ts";

function unwrap<T>(decision: Decision<T>): T {
  if (!decision.ok) {
    throw new HttpsError(decision.refusal.code, decision.refusal.message);
  }
  return decision.value;
}

function callerOf(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  return uid;
}

function dataOf(request: CallableRequest): Record<string, unknown> {
  const data: unknown = request.data;
  return typeof data === "object" && data !== null
    ? (data as Record<string, unknown>)
    : {};
}

function nameOf(request: CallableRequest): string {
  return memberName(request.auth?.token["name"]);
}

const kitchenRef = (db: Firestore, id: string) => db.doc(`kitchens/${id}`);
const userRef = (db: Firestore, uid: string) => db.doc(`users/${uid}`);

async function readKitchen(ref: DocumentReference): Promise<Kitchen | undefined> {
  return (await ref.get()).data() as Kitchen | undefined;
}

export const createKitchen = onCall(async (request) => {
  const uid = callerOf(request);
  const data = dataOf(request);
  const name = unwrap(parseKitchenName(data["name"]));
  const db = getFirestore();
  const kitchenIds = ((await userRef(db, uid).get()).data()?.["kitchenIds"] ??
    []) as string[];
  unwrap(canCreateKitchen(kitchenIds));
  const kitchen = db.collection("kitchens").doc();
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.create(kitchen, {
    name,
    ownerId: uid,
    memberIds: [uid],
    memberNames: { [uid]: nameOf(request) },
    language: parseLanguage(data["language"]),
    createdAt: now,
  });
  batch.set(
    userRef(db, uid),
    {
      name: nameOf(request),
      email: request.auth?.token["email"] ?? "",
      kitchenIds: FieldValue.arrayUnion(kitchen.id),
    },
    { merge: true },
  );
  for (const { id, ...tag } of defaultTags) {
    batch.create(kitchen.collection("tags").doc(id), { ...tag, createdAt: now });
  }
  for (const key of defaultStaples) {
    batch.create(kitchen.collection("staples").doc(keySlug(key)), {
      key,
      addedBy: uid,
      addedAt: now,
    });
  }
  await batch.commit();
  return { kitchenId: kitchen.id };
});

export const createInvite = onCall(async (request) => {
  const uid = callerOf(request);
  const kitchenId = unwrap(parseId(dataOf(request)["kitchenId"], "kitchen"));
  const db = getFirestore();
  unwrap(canInvite(await readKitchen(kitchenRef(db, kitchenId)), uid));

  const token = randomBytes(24).toString("base64url");
  const expiresAt = inviteExpiry(new Date());
  await db.doc(`invites/${token}`).create({
    kitchenId,
    createdBy: uid,
    expiresAt: Timestamp.fromDate(expiresAt),
  });
  return { token, expiresAt: expiresAt.toISOString() };
});

export const acceptInvite = onCall(async (request) => {
  const uid = callerOf(request);
  const token = unwrap(parseId(dataOf(request)["token"], "invite"));
  const db = getFirestore();

  const kitchenId = await db.runTransaction(async (transaction) => {
    const stored = (await transaction.get(db.doc(`invites/${token}`))).data();
    const invite: Invite | undefined =
      stored === undefined
        ? undefined
        : {
            kitchenId: stored["kitchenId"] as string,
            expiresAt: (stored["expiresAt"] as Timestamp).toDate(),
          };
    const kitchen =
      invite === undefined
        ? undefined
        : (await transaction.get(kitchenRef(db, invite.kitchenId))).data();
    const id = unwrap(acceptance(invite, kitchen as Kitchen | undefined, new Date()));

    transaction.update(kitchenRef(db, id), {
      memberIds: FieldValue.arrayUnion(uid),
      [`memberNames.${uid}`]: nameOf(request),
    });
    transaction.set(
      userRef(db, uid),
      {
        name: nameOf(request),
        email: request.auth?.token["email"] ?? "",
        kitchenIds: FieldValue.arrayUnion(id),
      },
      { merge: true },
    );
    return id;
  });
  return { kitchenId };
});

/**
 * Deletes a kitchen with everything in it. The kitchen stays listed on its
 * members until the very end, so that an interrupted deletion can be repeated
 * by leaving again. Invites go first, so that nobody can join halfway.
 */
/** Takes a kitchen that is gone off every user who still lists it. */
async function forgetEverywhere(db: Firestore, kitchenId: string): Promise<void> {
  const users = await db
    .collection("users")
    .where("kitchenIds", "array-contains", kitchenId)
    .get();
  const writer = db.bulkWriter();
  for (const user of users.docs) {
    void writer.update(user.ref, { kitchenIds: FieldValue.arrayRemove(kitchenId) });
  }
  await writer.close();
}

async function deleteKitchen(db: Firestore, kitchenId: string): Promise<void> {
  const ref = kitchenRef(db, kitchenId);
  const invites = await db
    .collection("invites")
    .where("kitchenId", "==", kitchenId)
    .get();
  const writer = db.bulkWriter();
  for (const invite of invites.docs) {
    void writer.delete(invite.ref);
  }
  await writer.close();

  const members = (await readKitchen(ref))?.memberIds ?? [];
  await getStorage().bucket().deleteFiles({ prefix: `kitchens/${kitchenId}/` });
  await db.recursiveDelete(ref);

  const batch = db.batch();
  for (const member of members) {
    batch.set(
      userRef(db, member),
      { kitchenIds: FieldValue.arrayRemove(kitchenId) },
      { merge: true },
    );
  }
  await batch.commit();
}

/**
 * The decision is made inside the transaction, so that it can't be overtaken
 * by a change of owner.
 */
async function leave(db: Firestore, kitchenId: string, uid: string): Promise<void> {
  const ref = kitchenRef(db, kitchenId);
  const user = userRef(db, uid);
  const forget = { kitchenIds: FieldValue.arrayRemove(kitchenId) };
  const outcome = await db.runTransaction(async (transaction) => {
    const kitchen = (await transaction.get(ref)).data() as Kitchen | undefined;
    const decided = unwrap(leaving(kitchen, uid));
    if (decided === "removeMember") {
      transaction.update(ref, {
        memberIds: FieldValue.arrayRemove(uid),
        [`memberNames.${uid}`]: FieldValue.delete(),
      });
    }
    if (decided !== "deleteKitchen") {
      transaction.set(user, forget, { merge: true });
    }
    return decided;
  });
  if (outcome === "deleteKitchen") {
    await deleteKitchen(db, kitchenId);
  }
  if (outcome === "forget") {
    await forgetEverywhere(db, kitchenId);
  }
}

export const leaveKitchen = onCall(async (request) => {
  const uid = callerOf(request);
  const kitchenId = unwrap(parseId(dataOf(request)["kitchenId"], "kitchen"));
  await leave(getFirestore(), kitchenId, uid);
  return {};
});

export const forgetKitchen = onCall(async (request) => {
  const uid = callerOf(request);
  const kitchenId = unwrap(parseId(dataOf(request)["kitchenId"], "kitchen"));
  const db = getFirestore();
  const kitchen = await readKitchen(kitchenRef(db, kitchenId));
  if (unwrap(forgetting(kitchen, uid)) === "everywhere") {
    await forgetEverywhere(db, kitchenId);
  } else {
    await userRef(db, uid).set(
      { kitchenIds: FieldValue.arrayRemove(kitchenId) },
      { merge: true },
    );
  }
  return {};
});

export const transferOwnership = onCall(async (request) => {
  const uid = callerOf(request);
  const data = dataOf(request);
  const kitchenId = unwrap(parseId(data["kitchenId"], "kitchen"));
  const newOwnerId = unwrap(parseId(data["newOwnerId"], "new owner"));
  const db = getFirestore();
  const ref = kitchenRef(db, kitchenId);
  await db.runTransaction(async (transaction) => {
    const kitchen = (await transaction.get(ref)).data() as Kitchen | undefined;
    unwrap(transfer(kitchen, uid, newOwnerId));
    transaction.update(ref, { ownerId: newOwnerId });
  });
  return {};
});

export const deleteAccount = onCall(async (request) => {
  const uid = callerOf(request);
  const db = getFirestore();
  const user = userRef(db, uid);
  const kitchenIds = ((await user.get()).data()?.["kitchenIds"] ?? []) as string[];
  for (const kitchenId of kitchenIds) {
    await leave(db, kitchenId, uid);
  }
  await user.delete();
  await getAuth().deleteUser(uid);
  return {};
});

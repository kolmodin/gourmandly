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
  canInvite,
  inviteExpiry,
  leaving,
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
  const kitchen = db.collection("kitchens").doc();
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.create(kitchen, {
    name,
    ownerId: uid,
    memberIds: [uid],
    language: parseLanguage(data["language"]),
    createdAt: now,
  });
  batch.set(
    userRef(db, uid),
    {
      name: request.auth?.token["name"] ?? "",
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
    });
    transaction.set(
      userRef(db, uid),
      {
        name: request.auth?.token["name"] ?? "",
        email: request.auth?.token["email"] ?? "",
        kitchenIds: FieldValue.arrayUnion(id),
      },
      { merge: true },
    );
    return id;
  });
  return { kitchenId };
});

/** Deletes a kitchen with everything in it, and all invites to it. */
async function deleteKitchen(
  db: Firestore,
  kitchenId: string,
  kitchen: Kitchen,
): Promise<void> {
  const batch = db.batch();
  for (const member of kitchen.memberIds) {
    batch.set(
      userRef(db, member),
      { kitchenIds: FieldValue.arrayRemove(kitchenId) },
      { merge: true },
    );
  }
  const invites = await db
    .collection("invites")
    .where("kitchenId", "==", kitchenId)
    .get();
  for (const invite of invites.docs) {
    batch.delete(invite.ref);
  }
  await batch.commit();
  await db.recursiveDelete(kitchenRef(db, kitchenId));
  await getStorage().bucket().deleteFiles({ prefix: `kitchens/${kitchenId}/` });
}

async function leave(db: Firestore, kitchenId: string, uid: string): Promise<void> {
  const ref = kitchenRef(db, kitchenId);
  const kitchen = await readKitchen(ref);
  switch (unwrap(leaving(kitchen, uid))) {
    case "deleteKitchen":
      await deleteKitchen(db, kitchenId, kitchen as Kitchen);
      break;
    case "removeMember": {
      const batch = db.batch();
      batch.update(ref, { memberIds: FieldValue.arrayRemove(uid) });
      batch.set(
        userRef(db, uid),
        { kitchenIds: FieldValue.arrayRemove(kitchenId) },
        { merge: true },
      );
      await batch.commit();
    }
  }
}

export const leaveKitchen = onCall(async (request) => {
  const uid = callerOf(request);
  const kitchenId = unwrap(parseId(dataOf(request)["kitchenId"], "kitchen"));
  await leave(getFirestore(), kitchenId, uid);
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

// The decisions behind membership changes, as pure functions.

/** Why a request can't be carried out. */
export type Refusal =
  | { code: "invalid-argument"; message: string }
  | { code: "not-found"; message: string }
  | { code: "permission-denied"; message: string }
  | { code: "failed-precondition"; message: string };

export type Decision<T> = { ok: true; value: T } | { ok: false; refusal: Refusal };

const ok = <T>(value: T): Decision<T> => ({ ok: true, value });
const refuse = (code: Refusal["code"], message: string): Decision<never> => ({
  ok: false,
  refusal: { code, message },
});

export interface Kitchen {
  ownerId: string;
  memberIds: string[];
}

export interface Invite {
  kitchenId: string;
  expiresAt: Date;
}

export const inviteLifetimeDays = 7;

const maxNameLength = 80;

/** Every kitchen costs writes and has its own quotas, so they can't be free. */
export const maxKitchensPerUser = 10;

export function inviteExpiry(now: Date): Date {
  return new Date(now.getTime() + inviteLifetimeDays * 24 * 60 * 60 * 1000);
}

export function parseKitchenName(name: unknown): Decision<string> {
  if (typeof name !== "string") {
    return refuse("invalid-argument", "A kitchen needs a name.");
  }
  const trimmed = name.trim();
  if (trimmed.length === 0 || trimmed.length > maxNameLength) {
    return refuse(
      "invalid-argument",
      `A kitchen name has 1 to ${maxNameLength} characters.`,
    );
  }
  return ok(trimmed);
}

/** The language of a new kitchen, from a tag like `sv` or `sv-SE`. */
export function parseLanguage(language: unknown): string {
  const code =
    typeof language === "string" ? language.split(/[-_]/)[0]?.toLowerCase() : "";
  return code !== undefined && /^[a-z]{2,3}$/.test(code) ? code : "en";
}

/** A value that is safe as a Firestore document ID. */
export function parseId(value: unknown, what: string): Decision<string> {
  return typeof value === "string" &&
    value.length > 0 &&
    !value.includes("/") &&
    !/^\.\.?$/.test(value) &&
    !/^__.*__$/.test(value)
    ? ok(value)
    : refuse("invalid-argument", `Missing or invalid ${what}.`);
}

export function canCreateKitchen(kitchenIds: string[]): Decision<true> {
  return kitchenIds.length < maxKitchensPerUser
    ? ok(true)
    : refuse("failed-precondition", "You have too many kitchens already.");
}

/** What other members see of a user. */
export function memberName(name: unknown): string {
  return typeof name === "string" ? name : "";
}

export function canInvite(kitchen: Kitchen | undefined, uid: string): Decision<true> {
  return kitchen?.memberIds.includes(uid) === true
    ? ok(true)
    : refuse("not-found", "No such kitchen.");
}

export function acceptance(
  invite: Invite | undefined,
  kitchen: Kitchen | undefined,
  now: Date,
): Decision<string> {
  if (invite === undefined || kitchen === undefined) {
    return refuse("not-found", "This invite isn't valid.");
  }
  if (invite.expiresAt.getTime() <= now.getTime()) {
    return refuse("failed-precondition", "This invite has expired.");
  }
  return ok(invite.kitchenId);
}

export type Leaving = "removeMember" | "deleteKitchen" | "forget";

/**
 * When the owner leaves, the kitchen and everything in it goes too. A kitchen
 * that is gone may still be listed on the user, after a deletion that was
 * interrupted or raced with an invite, and only needs forgetting.
 */
export function leaving(kitchen: Kitchen | undefined, uid: string): Decision<Leaving> {
  if (kitchen === undefined) return ok("forget");
  if (!kitchen.memberIds.includes(uid)) {
    return refuse("not-found", "No such kitchen.");
  }
  return ok(kitchen.ownerId === uid ? "deleteKitchen" : "removeMember");
}

export function transfer(
  kitchen: Kitchen | undefined,
  uid: string,
  newOwnerId: string,
): Decision<true> {
  if (kitchen?.memberIds.includes(uid) !== true) {
    return refuse("not-found", "No such kitchen.");
  }
  if (kitchen.ownerId !== uid) {
    return refuse("permission-denied", "Only the owner can hand over a kitchen.");
  }
  if (!kitchen.memberIds.includes(newOwnerId)) {
    return refuse("failed-precondition", "The new owner has to be a member.");
  }
  return ok(true);
}

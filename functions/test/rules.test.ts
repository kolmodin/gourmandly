// Security Rules tests. They run against the Firestore and Storage emulators,
// see the rules test step in scripts/test.sh.
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import type {
  RulesTestContext,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";

const firebaseDir = new URL("../../firebase/", import.meta.url);

let env: RulesTestEnvironment;

const alice = () => env.authenticatedContext("alice").firestore();
const bob = () => env.authenticatedContext("bob").firestore();
const stranger = () => env.authenticatedContext("mallory").firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

const openCollections = [
  "recipes",
  "tags",
  "staples",
  "plannedRecipes",
  "listItems",
  "checks",
  "overrides",
];

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-gourmandly",
    firestore: {
      rules: readFileSync(new URL("firestore.rules", firebaseDir), "utf8"),
    },
    storage: {
      rules: readFileSync(new URL("storage.rules", firebaseDir), "utf8"),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (context: RulesTestContext) => {
    const db = context.firestore();
    const kitchen = {
      name: "Hemma",
      ownerId: "alice",
      memberIds: ["alice", "bob"],
      language: "sv",
    };
    await setDoc(doc(db, "kitchens/k1"), kitchen);
    await setDoc(doc(db, "kitchens/other"), {
      ...kitchen,
      ownerId: "mallory",
      memberIds: ["mallory"],
    });
    for (const name of openCollections) {
      await setDoc(doc(db, `kitchens/k1/${name}/doc`), { a: 1 });
    }
    await setDoc(doc(db, "kitchens/k1/usage/2026-11"), { imports: 1 });
    await setDoc(doc(db, "kitchens/k1/importJobs/j1"), {
      url: "https://example.com",
      status: "pending",
    });
    await setDoc(doc(db, "users/alice"), { kitchenIds: ["k1"] });
    await setDoc(doc(db, "users/bob"), { kitchenIds: ["k1"] });
    await setDoc(doc(db, "invites/token"), { kitchenId: "k1" });
    await setDoc(doc(db, "meta/app"), { minSupportedVersion: 1 });
    await uploadBytes(
      ref(context.storage(), "kitchens/k1/recipes/r1/photo.jpg"),
      new Uint8Array([1, 2, 3]),
    );
  });
});

describe("kitchen documents", () => {
  it("members can read their kitchen", async () => {
    await assertSucceeds(getDoc(doc(bob(), "kitchens/k1")));
  });

  it("outsiders can't read it", async () => {
    await assertFails(getDoc(doc(stranger(), "kitchens/k1")));
    await assertFails(getDoc(doc(anonymous(), "kitchens/k1")));
  });

  it("nobody can read a kitchen that doesn't exist", async () => {
    await assertFails(getDoc(doc(alice(), "kitchens/missing")));
  });

  it("kitchens can't be listed", async () => {
    await assertFails(getDocs(collection(alice(), "kitchens")));
  });

  it("members can rename a kitchen and change its language", async () => {
    await assertSucceeds(
      updateDoc(doc(bob(), "kitchens/k1"), { name: "Nytt", language: "en" }),
    );
  });

  for (const [field, value] of [
    ["memberIds", ["alice", "bob", "mallory"]],
    ["ownerId", "bob"],
    ["somethingNew", 1],
  ] as const) {
    it(`members can't change ${field}`, async () => {
      await assertFails(
        updateDoc(doc(bob(), "kitchens/k1"), { [field]: value }),
      );
    });
  }

  it("a rename can't smuggle in a membership change", async () => {
    await assertFails(
      updateDoc(doc(bob(), "kitchens/k1"), {
        name: "Nytt",
        memberIds: ["bob"],
      }),
    );
  });

  it("outsiders can't add themselves", async () => {
    await assertFails(
      updateDoc(doc(stranger(), "kitchens/k1"), {
        memberIds: ["alice", "bob", "mallory"],
      }),
    );
  });

  it("clients can't create or delete kitchens", async () => {
    await assertFails(
      setDoc(doc(alice(), "kitchens/new"), {
        name: "Ny",
        ownerId: "alice",
        memberIds: ["alice"],
      }),
    );
    await assertFails(deleteDoc(doc(alice(), "kitchens/k1")));
  });
});

describe("kitchen contents", () => {
  for (const name of openCollections) {
    describe(name, () => {
      const path = `kitchens/k1/${name}`;

      it("members can read, list, create, update and delete", async () => {
        const db = bob();
        await assertSucceeds(getDoc(doc(db, `${path}/doc`)));
        await assertSucceeds(getDocs(collection(db, path)));
        await assertSucceeds(setDoc(doc(db, `${path}/new`), { a: 1 }));
        await assertSucceeds(updateDoc(doc(db, `${path}/doc`), { a: 2 }));
        await assertSucceeds(deleteDoc(doc(db, `${path}/doc`)));
      });

      it("outsiders can do none of that", async () => {
        for (const db of [stranger(), anonymous()]) {
          await assertFails(getDoc(doc(db, `${path}/doc`)));
          await assertFails(getDocs(collection(db, path)));
          await assertFails(setDoc(doc(db, `${path}/new`), { a: 1 }));
          await assertFails(updateDoc(doc(db, `${path}/doc`), { a: 2 }));
          await assertFails(deleteDoc(doc(db, `${path}/doc`)));
        }
      });
    });
  }

  it("a member of one kitchen can't reach another", async () => {
    await assertFails(getDocs(collection(alice(), "kitchens/other/recipes")));
    await assertFails(setDoc(doc(alice(), "kitchens/other/recipes/x"), {}));
  });

  it("an unknown collection is closed, even to members", async () => {
    await assertFails(getDoc(doc(alice(), "kitchens/k1/secrets/x")));
    await assertFails(setDoc(doc(alice(), "kitchens/k1/secrets/x"), {}));
  });
});

describe("import jobs", () => {
  const job = (uid = "alice") => ({
    url: "https://example.com/recipe",
    status: "pending",
    createdBy: uid,
    createdAt: serverTimestamp(),
  });

  it("members can create a pending job and read it", async () => {
    await assertSucceeds(setDoc(doc(alice(), "kitchens/k1/importJobs/j2"), job()));
    await assertSucceeds(getDoc(doc(bob(), "kitchens/k1/importJobs/j1")));
  });

  it("outsiders can't create or read jobs", async () => {
    await assertFails(
      setDoc(doc(stranger(), "kitchens/k1/importJobs/j2"), job("mallory")),
    );
    await assertFails(getDoc(doc(stranger(), "kitchens/k1/importJobs/j1")));
  });

  it("a job can't claim to be done already", async () => {
    await assertFails(
      setDoc(doc(alice(), "kitchens/k1/importJobs/j2"), {
        ...job(),
        status: "done",
      }),
    );
  });

  it("a job can't be created in someone else's name", async () => {
    await assertFails(
      setDoc(doc(alice(), "kitchens/k1/importJobs/j2"), job("bob")),
    );
  });

  it("a job can't carry extra fields", async () => {
    await assertFails(
      setDoc(doc(alice(), "kitchens/k1/importJobs/j2"), {
        ...job(),
        recipeId: "r1",
      }),
    );
  });

  it("a job needs a URL that is a string", async () => {
    await assertFails(
      setDoc(doc(alice(), "kitchens/k1/importJobs/j2"), { ...job(), url: 1 }),
    );
  });

  it("members can't update or delete jobs", async () => {
    await assertFails(
      updateDoc(doc(alice(), "kitchens/k1/importJobs/j1"), { status: "done" }),
    );
    await assertFails(deleteDoc(doc(alice(), "kitchens/k1/importJobs/j1")));
  });
});

describe("usage records", () => {
  it("members can read but not change them", async () => {
    const usage = "kitchens/k1/usage/2026-11";
    await assertSucceeds(getDoc(doc(alice(), usage)));
    await assertFails(updateDoc(doc(alice(), usage), { imports: 0 }));
    await assertFails(setDoc(doc(alice(), "kitchens/k1/usage/new"), {}));
    await assertFails(deleteDoc(doc(alice(), usage)));
  });

  it("outsiders can't read them", async () => {
    await assertFails(getDoc(doc(stranger(), "kitchens/k1/usage/2026-11")));
  });
});

describe("users", () => {
  it("a user can read their own document", async () => {
    await assertSucceeds(getDoc(doc(alice(), "users/alice")));
  });

  it("not anyone else's", async () => {
    await assertFails(getDoc(doc(alice(), "users/bob")));
    await assertFails(getDoc(doc(anonymous(), "users/bob")));
  });

  it("users can't change their own document", async () => {
    await assertFails(
      updateDoc(doc(alice(), "users/alice"), { kitchenIds: ["k1", "other"] }),
    );
    await assertFails(setDoc(doc(stranger(), "users/mallory"), { kitchenIds: ["k1"] }));
    await assertFails(deleteDoc(doc(alice(), "users/alice")));
  });
});

describe("invites", () => {
  it("clients can't touch invites at all", async () => {
    await assertFails(getDoc(doc(alice(), "invites/token")));
    await assertFails(getDoc(doc(stranger(), "invites/token")));
    await assertFails(getDocs(collection(alice(), "invites")));
    await assertFails(setDoc(doc(alice(), "invites/new"), { kitchenId: "k1" }));
  });
});

describe("app metadata", () => {
  it("anyone can read it", async () => {
    await assertSucceeds(getDoc(doc(anonymous(), "meta/app")));
  });

  it("nobody can change it", async () => {
    await assertFails(updateDoc(doc(alice(), "meta/app"), { importsEnabled: true }));
  });
});

describe("anything else", () => {
  it("is closed", async () => {
    await assertFails(getDoc(doc(alice(), "elsewhere/doc")));
    await assertFails(setDoc(doc(alice(), "elsewhere/doc"), {}));
  });
});

describe("recipe photos", () => {
  const photo = "kitchens/k1/recipes/r1/photo.jpg";
  const storage = (uid: string | null) =>
    (uid === null
      ? env.unauthenticatedContext()
      : env.authenticatedContext(uid)
    ).storage();

  it("members can read them", async () => {
    await assertSucceeds(getBytes(ref(storage("bob"), photo)));
  });

  it("outsiders can't", async () => {
    await assertFails(getBytes(ref(storage("mallory"), photo)));
    await assertFails(getBytes(ref(storage(null), photo)));
  });

  it("clients can't write them", async () => {
    await assertFails(
      uploadBytes(ref(storage("alice"), "kitchens/k1/recipes/r1/new.jpg"), new Uint8Array([1])),
    );
  });

  it("anything outside a kitchen is closed", async () => {
    await assertFails(uploadBytes(ref(storage("alice"), "elsewhere.jpg"), new Uint8Array([1])));
    await assertFails(getBytes(ref(storage("alice"), "elsewhere.jpg")));
  });
});

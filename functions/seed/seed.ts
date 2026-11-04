// Local development data for the emulators: a kitchen with two members, recipes
// with photos, and something in every stage of planning. Does nothing if the
// data is already there.
process.env["FIRESTORE_EMULATOR_HOST"] ??= "127.0.0.1:8080";
process.env["FIREBASE_AUTH_EMULATOR_HOST"] ??= "127.0.0.1:9099";
process.env["FIREBASE_STORAGE_EMULATOR_HOST"] ??= "127.0.0.1:9199";

import { readFile } from "node:fs/promises";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

import { defaultStaples, defaultTags, keySlug } from "../src/defaults.ts";

const projectId = "demo-gourmandly";
const kitchenId = "hemma";

initializeApp({ projectId, storageBucket: `${projectId}.appspot.com` });

interface Ingredient {
  id: string;
  text: string;
  name: string;
  key: string;
  quantity: { num: number; den: number } | null;
  unit: string | null;
  group?: string;
  boughtAs?: string;
}

/**
 * `[amount, unit, name, key, boughtAs?]`, where the amount is `n`, `[n, d]` or
 * null.
 */
type Row = [
  number | [number, number] | null,
  string | null,
  string,
  string,
  string?,
];

function ingredients(rows: Row[], group?: string): Ingredient[] {
  return rows.map(([amount, unit, name, key, boughtAs], index) => {
    const [num, den] = Array.isArray(amount) ? amount : [amount, 1];
    const shown = Array.isArray(amount) ? `${amount[0]}/${amount[1]}` : amount;
    return {
      id: `${group ?? "i"}-${index}`,
      text: [shown, unit, name].filter((part) => part !== null).join(" "),
      name,
      key,
      quantity: num === null ? null : { num, den: den as number },
      unit,
      ...(group === undefined ? {} : { group }),
      ...(boughtAs === undefined ? {} : { boughtAs }),
    };
  });
}

interface Recipe {
  id: string;
  title: string;
  servings: number;
  totalTime: number;
  tags: string[];
  ingredients: Ingredient[];
  steps: string[];
  original?: { language: string; title: string; ingredients: Ingredient[]; steps: string[] };
}

const recipes: Recipe[] = [
  {
    id: "carbonara",
    title: "Spaghetti carbonara",
    servings: 4,
    totalTime: 25,
    tags: ["cuisine-italian", "effort-quick", "meal-dinner", "meatfish-pork"],
    ingredients: ingredients([
      [400, "g", "spaghetti", "spaghetti"],
      [150, "g", "guanciale eller pancetta", "pancetta"],
      [4, "st", "äggulor", "egg", "ägg"],
      [1, "dl", "riven pecorino", "pecorino"],
      [null, null, "svartpeppar", "black pepper"],
      [null, null, "salt", "salt"],
    ]),
    steps: [
      "Koka spaghettin i rikligt med saltat vatten. Spara en kopp av kokvattnet.",
      "Stek pancettan knaprig på medelvärme.",
      "Vispa äggulor och pecorino med mycket svartpeppar.",
      "Ta pannan från värmen, vänd ner pastan och äggblandningen. Späd med kokvatten tills såsen blir krämig.",
    ],
  },
  {
    id: "padthai",
    title: "Pad thai med räkor",
    servings: 2,
    totalTime: 30,
    tags: ["cuisine-thai", "cuisine-asian", "effort-everyday", "meal-dinner", "meatfish-seafood"],
    ingredients: [
      ...ingredients([
        [200, "g", "risnudlar", "rice noodles"],
        [200, "g", "räkor", "prawns"],
        [2, "st", "ägg", "egg"],
        [2, "dl", "böngroddar", "bean sprouts"],
        [1, "kruka", "koriander", "coriander"],
        [1, "st", "lime", "lime"],
      ]),
      ...ingredients(
        [
          [3, "msk", "fisksås", "fish sauce"],
          [2, "msk", "tamarindpasta", "tamarind paste"],
          [2, "msk", "farinsocker", "brown sugar"],
        ],
        "Sås",
      ),
    ],
    steps: [
      "Lägg nudlarna i ljummet vatten i 20 minuter.",
      "Rör ihop fisksås, tamarind och farinsocker.",
      "Stek räkorna snabbt, lägg åt sidan. Stek äggen och nudlarna.",
      "Häll i såsen, vänd ner räkor och böngroddar. Servera med lime och koriander.",
    ],
  },
  {
    id: "kottbullar",
    title: "Köttbullar med äggnudlar",
    servings: 4,
    totalTime: 45,
    tags: ["cuisine-nordic", "effort-everyday", "meal-dinner", "meatfish-beef", "meatfish-pork"],
    ingredients: ingredients([
      [500, "g", "blandfärs", "minced meat"],
      [1, "st", "gul lök", "yellow onion"],
      [1, "st", "ägg", "egg"],
      [1, "dl", "ströbröd", "breadcrumbs"],
      [1, "dl", "mjölk", "milk"],
      [400, "g", "äggnudlar", "egg noodles"],
      [2, "dl", "vispgrädde", "cream"],
    ]),
    steps: [
      "Blanda ströbröd och mjölk och låt svälla i tio minuter.",
      "Finhacka löken och fräs den mjuk.",
      "Blanda allt med färsen, rulla bullar och stek dem runt om.",
      "Koka nudlarna och gör en gräddsås i stekpannan.",
    ],
  },
  {
    id: "linssoppa",
    title: "Linssoppa med spiskummin",
    servings: 4,
    totalTime: 35,
    tags: ["cuisine-middle-eastern", "diet-vegetarian", "diet-vegan", "effort-everyday", "meal-dinner"],
    ingredients: ingredients([
      [3, "dl", "röda linser", "red lentils"],
      [1, "st", "gul lök", "yellow onion"],
      [2, "klyftor", "vitlök", "garlic"],
      [2, "st", "morötter", "carrot"],
      [1, "tsk", "spiskummin", "cumin"],
      [1, "l", "grönsaksbuljong", "vegetable stock"],
      [[1, 2], "st", "citron", "lemon"],
    ]),
    steps: [
      "Fräs lök, vitlök och morot i olja.",
      "Tillsätt spiskummin, linser och buljong. Låt sjuda i 20 minuter.",
      "Mixa slätt och smaka av med citron.",
    ],
  },
  {
    id: "fisksoppa",
    title: "Fisksoppa med saffran",
    servings: 4,
    totalTime: 40,
    tags: ["cuisine-mediterranean", "effort-ambitious", "meal-dinner", "meatfish-fish", "meatfish-seafood"],
    ingredients: ingredients([
      [400, "g", "torskfilé", "cod"],
      [200, "g", "räkor", "prawns"],
      [1, "st", "fänkål", "fennel"],
      [1, "st", "gul lök", "yellow onion"],
      [1, "burk", "krossade tomater", "crushed tomatoes"],
      [1, "dl", "vitt vin", "white wine"],
      [8, "dl", "fiskbuljong", "fish stock"],
      [1, "krm", "saffran", "saffron"],
    ]),
    steps: [
      "Fräs lök och fänkål mjukt.",
      "Häll i vin, tomater, buljong och saffran. Låt sjuda i 15 minuter.",
      "Lägg i fisken och låt den sjuda klart i fem minuter.",
      "Vänd ner räkorna precis innan servering.",
    ],
  },
  {
    id: "loksoppa",
    title: "Löksoppa med gratinerat bröd",
    servings: 4,
    totalTime: 75,
    tags: ["cuisine-french", "diet-vegetarian", "effort-ambitious", "meal-starter"],
    ingredients: ingredients([
      [1, "kg", "gul lök", "yellow onion"],
      [50, "g", "smör", "butter"],
      [1, "dl", "vitt vin", "white wine"],
      [1, "l", "grönsaksbuljong", "vegetable stock"],
      [4, "skivor", "lantbröd", "country bread"],
      [2, "dl", "riven gruyère", "gruyere"],
    ]),
    steps: [
      "Skiva löken och låt den fräsa i smöret på låg värme i 40 minuter.",
      "Häll i vin och buljong och låt sjuda i 20 minuter.",
      "Lägg bröd och ost på soppan i ugnsformar och gratinera under grillen.",
    ],
  },
  {
    id: "pannkakor",
    title: "Pannkakor med lingon",
    servings: 4,
    totalTime: 30,
    tags: ["cuisine-nordic", "diet-vegetarian", "effort-quick", "meal-dessert"],
    ingredients: ingredients([
      [3, "dl", "vetemjöl", "flour"],
      [6, "dl", "mjölk", "milk"],
      [3, "st", "ägg", "egg"],
      [2, "msk", "smör", "butter"],
      [2, "dl", "rårörda lingon", "lingonberries"],
    ]),
    steps: [
      "Vispa mjöl och hälften av mjölken till en slät smet.",
      "Vispa i resten av mjölken och äggen.",
      "Stek tunna pannkakor i smör och servera med lingon.",
    ],
  },
  {
    id: "kycklinggryta",
    title: "Kycklinggryta med bönor",
    servings: 4,
    totalTime: 50,
    tags: ["cuisine-american", "effort-everyday", "meal-dinner", "meatfish-chicken"],
    ingredients: ingredients([
      [600, "g", "kycklinglårfilé", "chicken thigh"],
      [2, "burkar", "pintobönor", "pinto beans"],
      [1, "st", "gul lök", "yellow onion"],
      [3, "klyftor", "vitlök", "garlic"],
      [2, "st", "grön paprika", "green pepper"],
      [5, "dl", "kycklingbuljong", "chicken stock"],
    ]),
    steps: [
      "Bryn kycklingen och lägg åt sidan.",
      "Fräs lök, vitlök och paprika.",
      "Lägg i bönor, buljong och kyckling. Låt sjuda i 30 minuter.",
    ],
  },
  {
    id: "shakshuka",
    title: "Shakshuka",
    servings: 2,
    totalTime: 30,
    tags: ["cuisine-middle-eastern", "diet-vegetarian", "effort-quick", "meal-lunch"],
    ingredients: ingredients([
      [4, "st", "ägg", "egg"],
      [2, "burkar", "krossade tomater", "crushed tomatoes"],
      [1, "st", "röd paprika", "red pepper"],
      [1, "st", "gul lök", "yellow onion"],
      [2, "klyftor", "vitlök", "garlic"],
      [1, "tsk", "paprikapulver", "paprika"],
      [1, "tsk", "spiskummin", "cumin"],
    ]),
    steps: [
      "Fräs lök, paprika och vitlök mjukt med kryddorna.",
      "Häll i tomaterna och låt koka ihop i tio minuter.",
      "Gör gropar i såsen, knäck i äggen och lägg på lock tills vitorna stelnat.",
    ],
    original: {
      language: "en",
      title: "Shakshuka",
      ingredients: ingredients([
        [4, "st", "eggs", "egg"],
        [2, "burkar", "crushed tomatoes", "crushed tomatoes"],
        [1, "st", "red bell pepper", "red pepper"],
        [1, "st", "yellow onion", "yellow onion"],
        [2, "klyftor", "garlic", "garlic"],
        [1, "tsk", "paprika", "paprika"],
        [1, "tsk", "cumin", "cumin"],
      ]),
      steps: [
        "Soften the onion, pepper and garlic with the spices.",
        "Add the tomatoes and simmer for ten minutes.",
        "Make wells in the sauce, crack in the eggs and cover until the whites set.",
      ],
    },
  },
];

const photos: Record<string, string> = {
  carbonara: "carbonara",
  padthai: "padthai",
  kottbullar: "kottbullar",
  linssoppa: "lins",
  fisksoppa: "fisk",
  loksoppa: "lok",
  pannkakor: "pannkakor",
  kycklinggryta: "kyckling",
  shakshuka: "shakshuka",
};

const members = [
  { uid: "anna", email: "anna@example.com", displayName: "Anna" },
  { uid: "erik", email: "erik@example.com", displayName: "Erik" },
];

async function seed(): Promise<void> {
  const db = getFirestore();
  const kitchen = db.doc(`kitchens/${kitchenId}`);
  if ((await kitchen.get()).exists) {
    return;
  }

  for (const member of members) {
    await getAuth().createUser({ ...member, password: "gourmandly" });
    await db.doc(`users/${member.uid}`).set({
      name: member.displayName,
      email: member.email,
      kitchenIds: [kitchenId],
    });
  }
  await kitchen.set({
    name: "Hemma",
    ownerId: "anna",
    memberIds: members.map((member) => member.uid),
    memberNames: { anna: "Anna", erik: "Erik" },
    language: "sv",
    createdAt: Timestamp.now(),
  });

  const now = Timestamp.now();
  const batch = db.batch();
  for (const { id, ...tag } of defaultTags) {
    batch.set(kitchen.collection("tags").doc(id), { ...tag, createdAt: now });
  }
  for (const key of defaultStaples) {
    batch.set(kitchen.collection("staples").doc(keySlug(key)), {
      key,
      addedBy: "anna",
      addedAt: now,
    });
  }
  await batch.commit();

  const bucket = getStorage().bucket();
  const directory = new URL("../../firebase/seed/photos/", import.meta.url);
  for (const { id, tags, ...recipe } of recipes) {
    const path = `kitchens/${kitchenId}/recipes/${id}/photo.jpg`;
    await bucket.file(path).save(
      await readFile(new URL(`${photos[id] as string}.jpg`, directory)),
      { contentType: "image/jpeg" },
    );
    await kitchen.collection("recipes").doc(id).set({
      ...recipe,
      tagIds: tags,
      language: "sv",
      image: { storagePath: path, origin: "page" },
      importMethod: "manual",
      createdBy: "anna",
      createdAt: now,
    });
  }

  const planned = kitchen.collection("plannedRecipes");
  const entry = { addedBy: "anna", addedAt: now, excluded: [], done: [] };
  await planned.doc("e-carbonara").set({ ...entry, recipeId: "carbonara", servings: 4 });
  await planned.doc("e-padthai").set({ ...entry, recipeId: "padthai", servings: 4 });
  await planned.doc("e-linssoppa").set({
    ...entry,
    recipeId: "linssoppa",
    servings: 4,
    addedBy: "erik",
  });
  await planned.doc("e-fisksoppa").set({
    ...entry,
    recipeId: "fisksoppa",
    servings: 4,
    shoppedAt: now,
    cookingStartedAt: now,
  });
  await planned.doc("e-shakshuka").set({
    ...entry,
    recipeId: "shakshuka",
    servings: 2,
    shoppedAt: now,
  });
  await planned.doc("e-pannkakor").set({
    ...entry,
    recipeId: "pannkakor",
    servings: 4,
    shoppedAt: now,
  });
  await kitchen.collection("listItems").doc("mjolk").set({
    name: "mjölk",
    addedBy: "erik",
    addedAt: now,
  });
  await kitchen.collection("listItems").doc("kaffe").set({
    name: "kaffe",
    addedBy: "anna",
    addedAt: now,
  });
  await kitchen.collection("checks").doc("spaghetti--mass").set({
    key: "spaghetti",
    dimension: "mass",
    checkedQuantity: { num: 400, den: 1 },
    checkedBy: "erik",
    checkedAt: now,
  });
}

await seed();
process.exit(0);

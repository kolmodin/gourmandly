// Imported first by every module that declares a Function: declarations pick
// up the global options as they run, and imports run before a module's body.
import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

initializeApp();
setGlobalOptions({ region: "europe-north1", maxInstances: 10 });

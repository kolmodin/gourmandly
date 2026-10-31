import { onRequest } from "firebase-functions/v2/https";

// Liveness check, used to verify that the Functions emulator and the build
// are wired up.
export const health = onRequest((_request, response) => {
  response.json({ status: "ok" });
});

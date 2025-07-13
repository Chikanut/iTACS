/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const functions = require("firebase-functions");
const fetch = require("node-fetch");
const cors = require("cors")({ origin: true });

exports.proxyDownload = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const fileId = req.query.fileId;
    if (!fileId) {
      return res.status(400).send("Missing fileId");
    }

    const driveUrl = `https://drive.google.com/uc?id=${fileId}&export=download`;

    try {
      const response = await fetch(driveUrl);
      if (!response.ok) {
        throw new Error(`Failed with status ${response.status}`);
      }

      const buffer = await response.buffer();
      const contentType = response.headers.get("content-type") || "application/octet-stream";

      res.setHeader("Content-Type", contentType);
      res.send(buffer);
    } catch (error) {
      console.error("Download error:", error);
      res.status(500).send("Failed to download file");
    }
  });
});

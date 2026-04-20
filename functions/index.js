const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {onDocumentCreated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");

admin.initializeApp();

setGlobalOptions({
  region: "asia-south1",
  maxInstances: 10,
});

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendNotificationPush = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("Notification trigger received without snapshot data.");
      return;
    }

    const notificationId = event.params.notificationId;
    const data = snapshot.data() || {};
    const userId = normalizeString(data.userId);
    const body = normalizeString(data.message);

    if (!userId || !body) {
      logger.warn("Notification missing userId or message.", {
        notificationId,
        userId,
      });
      await snapshot.ref.set(
        {
          push: {
            status: "skipped",
            reason: "missing-user-or-message",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
      return;
    }

    const userSnap = await db.collection("users").doc(userId).get();
    if (!userSnap.exists) {
      logger.warn("Target user not found for notification.", {
        notificationId,
        userId,
      });
      await snapshot.ref.set(
        {
          push: {
            status: "skipped",
            reason: "user-not-found",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
      return;
    }

    const userData = userSnap.data() || {};
    const tokens = Array.from(
      new Set(
        (Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [])
            .map((token) => normalizeString(token))
            .filter(Boolean),
      ),
    );

    if (tokens.length === 0) {
      logger.info("User has no registered FCM tokens.", {
        notificationId,
        userId,
      });
      await snapshot.ref.set(
        {
          push: {
            status: "skipped",
            reason: "no-fcm-tokens",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
      return;
    }

    const title = buildTitle(data);
    const payload = {
      notification: {
        title,
        body,
      },
      data: buildDataPayload(data, notificationId),
      android: {
        priority: "high",
        notification: {
          channelId: "wegovroom_notifications",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
      tokens,
    };

    const response = await messaging.sendEachForMulticast(payload);
    const invalidTokens = [];

    response.responses.forEach((result, index) => {
      if (result.success) return;

      const code = result.error && result.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await userSnap.ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }

    await snapshot.ref.set(
      {
        push: {
          status: response.successCount > 0 ? "sent" : "failed",
          title,
          successCount: response.successCount,
          failureCount: response.failureCount,
          invalidTokensRemoved: invalidTokens.length,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );

    logger.info("Processed push notification delivery.", {
      notificationId,
      userId,
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidTokensRemoved: invalidTokens.length,
    });
  },
);

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildTitle(notification) {
  const actorName = normalizeString(notification.actorName);
  const type = normalizeString(notification.type);

  switch (type) {
    case "trip_request":
      return actorName ? `${actorName} sent a trip request` : "New trip request";
    case "trip_joined":
      return actorName ? `${actorName} joined your trip` : "Trip joined";
    case "trip_left":
      return actorName ? `${actorName} left your trip` : "Trip update";
    case "trip_removed":
      return "Trip participant update";
    case "trip_request_approved":
      return "Trip request approved";
    case "trip_request_rejected":
      return "Trip request rejected";
    case "admin_announcement":
      return "Announcement";
    default:
      return "WeGoVroom";
  }
}

function buildDataPayload(notification, notificationId) {
  const payload = {
    notificationId,
    type: normalizeString(notification.type) || "general",
  };

  const tripId = normalizeString(notification.tripId);
  const actorId = normalizeString(notification.actorId);
  const actorName = normalizeString(notification.actorName);

  if (tripId) payload.tripId = tripId;
  if (actorId) payload.actorId = actorId;
  if (actorName) payload.actorName = actorName;

  return payload;
}

exports.syncTripJoinedOnParticipantCreate = onDocumentCreated(
  "tripParticipants/{participantId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data() || {};
    const tripId = normalizeString(data.tripId);
    if (!tripId) return;

    await syncTripJoinedCount(tripId);
  },
);

exports.syncTripJoinedOnParticipantDelete = onDocumentDeleted(
  "tripParticipants/{participantId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data() || {};
    const tripId = normalizeString(data.tripId);
    if (!tripId) return;

    await syncTripJoinedCount(tripId);
  },
);

async function syncTripJoinedCount(tripId) {
  const tripRef = db.collection("trips").doc(tripId);
  const tripSnap = await tripRef.get();
  if (!tripSnap.exists) return;

  const participantSnap = await db
      .collection("tripParticipants")
      .where("tripId", "==", tripId)
      .get();

  const joined = participantSnap.size;
  const safeJoined = joined < 1 ? 1 : joined;

  await tripRef.set({joined: safeJoined}, {merge: true});
}
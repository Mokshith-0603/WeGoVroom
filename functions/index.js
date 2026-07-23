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
    case "trip_merge_request":
      return "Matching trip found";
    case "trip_merge_completed":
      return "Trips merged";
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

function normalizedDestination(value) {
  return normalizeString(value).toLocaleLowerCase("en").replace(/\s+/g, " ");
}

function tripHasVacancy(data) {
  const joined = Number.isFinite(data.joined) ? data.joined : 1;
  const maxPeople = Number.isFinite(data.maxPeople) ? data.maxPeople : 4;
  return joined < maxPeople;
}

function tripCanMerge(data) {
  const dateTime = data.dateTime && data.dateTime.toDate ?
    data.dateTime.toDate() :
    null;
  return Boolean(
    dateTime &&
    dateTime.getTime() > Date.now() &&
    data.completed !== true &&
    data.cancelled !== true &&
    data.status !== "cancelled" &&
    data.status !== "merged" &&
    tripHasVacancy(data),
  );
}

exports.createTripMergeRequests = onDocumentCreated(
  {
    document: "trips/{tripId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const tripId = event.params.tripId;
    const trip = snapshot.data() || {};
    const ownerId = normalizeString(trip.ownerId);
    const destination = normalizedDestination(trip.to);
    const dateTime = trip.dateTime;
    if (!ownerId || !destination || !dateTime || !tripCanMerge(trip)) return;

    const candidates = await db
        .collection("trips")
        .where("dateTime", "==", dateTime)
        .get();

    const writes = [];
    for (const candidate of candidates.docs) {
      if (candidate.id === tripId) continue;
      const other = candidate.data() || {};
      const otherOwnerId = normalizeString(other.ownerId);
      if (
        !otherOwnerId ||
        otherOwnerId === ownerId ||
        normalizedDestination(other.to) !== destination ||
        !tripCanMerge(other)
      ) {
        continue;
      }

      const tripIds = [tripId, candidate.id].sort();
      const requestId = tripIds.join("_");
      const hostsByTrip = {
        [tripId]: ownerId,
        [candidate.id]: otherOwnerId,
      };
      const hostIds = tripIds.map((id) => hostsByTrip[id]);
      const requestRef = db.collection("tripMergeRequests").doc(requestId);

      writes.push(db.runTransaction(async (transaction) => {
        const existing = await transaction.get(requestRef);
        if (existing.exists) return;

        transaction.create(requestRef, {
          tripIds,
          hostIds,
          destination: normalizeString(trip.to),
          dateTime,
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        for (const hostId of hostIds) {
          const otherHostId = hostIds.find((id) => id !== hostId);
          transaction.set(
              db.collection("users")
                  .doc(hostId)
                  .collection("tripMergeRequests")
                  .doc(requestId),
              {
                requestId,
                tripIds,
                hostIds,
                destination: normalizeString(trip.to),
                dateTime,
                status: "pending",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              },
          );
          transaction.create(db.collection("notifications").doc(), {
            userId: hostId,
            message: "Another trip has the same destination and time. Review the merge request.",
            type: "trip_merge_request",
            tripId: hostsByTrip[tripId] === hostId ? tripId : candidate.id,
            actorId: otherHostId || "",
            actorName: "",
            mergeRequestId: requestId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }));
    }

    await Promise.all(writes);
  },
);

exports.processTripMergeAcceptance = onDocumentCreated(
  {
    document: "tripMergeRequests/{requestId}/acceptances/{hostId}",
    region: "us-central1",
  },
  async (event) => {
    const acceptance = event.data;
    if (!acceptance) return;

    const {requestId} = event.params;
    const requestRef = db.collection("tripMergeRequests").doc(requestId);
    if (acceptance.data().accepted !== true) {
      await db.runTransaction(async (transaction) => {
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists || requestSnap.data().status !== "pending") return;
        const hostIds = Array.isArray(requestSnap.data().hostIds) ?
          requestSnap.data().hostIds :
          [];
        transaction.update(requestRef, {
          status: "declined",
          declinedBy: event.params.hostId,
          decidedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        for (const hostId of hostIds) {
          transaction.set(
              db.collection("users")
                  .doc(hostId)
                  .collection("tripMergeRequests")
                  .doc(requestId),
              {
                status: "declined",
                declinedBy: event.params.hostId,
                decidedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              {merge: true},
          );
        }
      });
      return;
    }

    await db.runTransaction(async (transaction) => {
      const requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) return;

      const request = requestSnap.data() || {};
      if (request.status !== "pending") return;
      const tripIds = Array.isArray(request.tripIds) ? request.tripIds : [];
      const hostIds = Array.isArray(request.hostIds) ? request.hostIds : [];
      if (tripIds.length !== 2 || hostIds.length !== 2) return;

      const acceptanceRefs = hostIds.map((id) =>
        requestRef.collection("acceptances").doc(id));
      const acceptanceSnaps = await Promise.all(
          acceptanceRefs.map((ref) => transaction.get(ref)),
      );
      if (!acceptanceSnaps.every((snap) =>
        snap.exists && snap.data().accepted === true)) {
        return;
      }

      const tripRefs = tripIds.map((id) => db.collection("trips").doc(id));
      const tripSnaps = await Promise.all(
          tripRefs.map((ref) => transaction.get(ref)),
      );
      if (!tripSnaps.every((snap) => snap.exists)) {
        transaction.update(requestRef, {
          status: "cancelled",
          failureReason: "trip-not-found",
          decidedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const trips = tripSnaps.map((snap) => snap.data() || {});
      if (
        !trips.every(tripCanMerge) ||
        normalizedDestination(trips[0].to) !== normalizedDestination(trips[1].to) ||
        trips[0].dateTime.toMillis() !== trips[1].dateTime.toMillis()
      ) {
        transaction.update(requestRef, {
          status: "cancelled",
          failureReason: "trips-no-longer-match",
          decidedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const participantQueries = tripIds.map((id) =>
        db.collection("tripParticipants").where("tripId", "==", id));
      const participantSnaps = await Promise.all(
          participantQueries.map((query) => transaction.get(query)),
      );
      const primaryId = tripIds[0];
      const secondaryId = tripIds[1];
      const participants = new Map();
      for (const snap of participantSnaps) {
        for (const doc of snap.docs) {
          const data = doc.data() || {};
          const userId = normalizeString(data.userId);
          if (userId && !participants.has(userId)) participants.set(userId, data);
        }
      }

      const totalCapacity = trips.reduce(
          (sum, trip) => sum + (Number.isFinite(trip.maxPeople) ? trip.maxPeople : 4),
          0,
      );
      transaction.update(tripRefs[0], {
        maxPeople: Math.max(totalCapacity, participants.size),
        joined: participants.size,
        mergedTripIds: admin.firestore.FieldValue.arrayUnion(secondaryId),
        mergedHostIds: admin.firestore.FieldValue.arrayUnion(...hostIds),
        mergedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(tripRefs[1], {
        status: "merged",
        completed: true,
        mergedIntoTripId: primaryId,
        mergedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      for (const [userId, data] of participants.entries()) {
        transaction.set(
            db.collection("tripParticipants").doc(`${primaryId}_${userId}`),
            {
              ...data,
              tripId: primaryId,
              isHost: userId === normalizeString(trips[0].ownerId),
            },
            {merge: true},
        );
      }
      for (const doc of participantSnaps[1].docs) {
        transaction.delete(doc.ref);
      }

      transaction.update(requestRef, {
        status: "merged",
        mergedTripId: primaryId,
        decidedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      for (const hostId of hostIds) {
        transaction.set(
            db.collection("users")
                .doc(hostId)
                .collection("tripMergeRequests")
                .doc(requestId),
            {
              status: "merged",
              mergedTripId: primaryId,
              decidedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        transaction.create(db.collection("notifications").doc(), {
          userId: hostId,
          message: "Both hosts accepted. The matching trips have been merged.",
          type: "trip_merge_completed",
          tripId: primaryId,
          actorId: "",
          actorName: "",
          mergeRequestId: requestId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
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

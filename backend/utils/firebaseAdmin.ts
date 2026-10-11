import admin from "firebase-admin";

let warnedMissingServiceAccount = false;

const getMessaging = () => {
  if (admin.apps.length === 0) {
    const rawServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!rawServiceAccount) {
      if (!warnedMissingServiceAccount) {
        console.warn(
          "Firebase push is disabled: FIREBASE_SERVICE_ACCOUNT_JSON is not configured.",
        );
        warnedMissingServiceAccount = true;
      }
      return null;
    }

    try {
      const serviceAccount = JSON.parse(rawServiceAccount);
      serviceAccount.private_key = serviceAccount.private_key?.replace(
        /\\n/g,
        "\n",
      );
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } catch (error) {
      console.error("Firebase Admin configuration is invalid.", error);
      return null;
    }
  }

  return admin.messaging();
};

export const sendPushNotification = async (
  user: { pushSubscriptions: string[]; save: () => Promise<unknown> },
  payload: { title: string; message: string; link?: string },
) => {
  if (!user?.pushSubscriptions?.length) return;

  const messaging = getMessaging();
  if (!messaging) return;

  const tokens = user.pushSubscriptions;
  const response = await messaging.sendEachForMulticast({
    data: {
      title: payload.title,
      message: payload.message,
      link: payload.link || "/",
    },
    tokens,
  });

  if (response.failureCount > 0) {
    const validTokens = tokens.filter(
      (_, index) => response.responses[index].success,
    );
    if (validTokens.length !== tokens.length) {
      user.pushSubscriptions = validTokens;
      await user.save();
    }
  }
};

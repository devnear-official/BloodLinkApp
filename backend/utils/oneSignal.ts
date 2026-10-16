const ONE_SIGNAL_API_URL = "https://api.onesignal.com/notifications";

let warnedMissingConfiguration = false;

export async function sendMobilePushNotification(
  userIds: string | string[],
  payload: { title: string; message: string; link?: string },
): Promise<boolean> {
  const appId = process.env.ONESIGNAL_APP_ID;
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!appId || !apiKey) {
    if (!warnedMissingConfiguration) {
      console.warn(
        "Mobile push is disabled: ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY are required.",
      );
      warnedMissingConfiguration = true;
    }
    return false;
  }

  const response = await fetch(ONE_SIGNAL_API_URL, {
    method: "POST",
    headers: {
      Authorization: `Key ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      app_id: appId,
      include_aliases: {
        external_id: Array.isArray(userIds) ? userIds : [userIds],
      },
      target_channel: "push",
      headings: { en: payload.title },
      contents: { en: payload.message },
      data: { link: payload.link ?? "/" },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `OneSignal push failed (${response.status}): ${body || response.statusText}`,
    );
  }

  return true;
}

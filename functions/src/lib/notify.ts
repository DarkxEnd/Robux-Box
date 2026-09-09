import {cols, subcols, messaging, userDoc, Timestamp} from "./admin";

export interface UserNotification {
  type: "reward" | "redemption" | "vip" | "referral" | "system" | "support";
  title: string;
  body: string;
  deeplink?: string;
  data?: Record<string, string>;
}

/**
 * Writes an in-app notification and, when the user has an FCM token and has
 * not muted that category, sends a push too. Delivery failures never bubble
 * up: a push that fails must not fail the economic action that triggered it.
 */
export async function sendUserNotification(
    uid: string,
    n: UserNotification,
): Promise<void> {
  try {
    await subcols.notifications(uid).add({
      ...n,
      read: false,
      createdAt: Timestamp.now(),
    });
  } catch (e) {
    console.error("sendUserNotification: failed to write in-app doc", e);
  }

  try {
    const snap = await userDoc(uid).get();
    const data = snap.data();
    const token = data?.fcmToken as string | undefined;
    const prefs = (data?.notificationPrefs as Record<string, boolean>) ?? {};
    if (!token) return;
    if (prefs[n.type] === false) return;

    await messaging.send({
      token,
      notification: {title: n.title, body: n.body},
      data: {
        type: n.type,
        deeplink: n.deeplink ?? "",
        ...(n.data ?? {}),
      },
      android: {
        priority: "high",
        notification: {channelId: "robux_box_default"},
      },
    });
  } catch (e) {
    // An invalid/expired token is normal churn, not an error worth alarming on.
    console.warn("sendUserNotification: push failed", (e as Error)?.message);
  }
}

/**
 * Emails the admin addresses configured in `config/notifications`. No-ops
 * silently until at least one address is set, and requires the Trigger Email
 * extension to actually deliver (see docs/DEPLOYMENT.md).
 */
export async function notifyAdmins(
    subject: string,
    body: string,
): Promise<void> {
  try {
    const snap = await cols.config.doc("notifications").get();
    const emails = (snap.data()?.adminEmails as string[]) ?? [];
    if (emails.length === 0) return;
    await cols.config.firestore.collection("mail").add({
      to: emails,
      message: {subject, text: body},
    });
  } catch (e) {
    console.error("notifyAdmins failed", e);
  }
}

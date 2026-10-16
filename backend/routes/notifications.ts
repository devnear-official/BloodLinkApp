import express from "express";
import Notification from "../models/Notification.ts";
import User from "../models/User.ts";
import { verifyToken } from "../middleware/auth.ts";
import { sendMobilePushNotification } from "../utils/oneSignal.ts";

const router = express.Router();

router.post("/test-push", verifyToken, async (req: any, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    const notification = await Notification.create({
      user: user._id,
      title: "Test notification",
      message: "BloodLink push notifications are working.",
      type: "test",
      link: "/profile",
    });

    req.app
      .get("io")
      ?.to(user._id.toString())
      .emit("notification:new", notification.toObject());

    void sendMobilePushNotification(user._id.toString(), {
      title: "Test notification",
      message: "BloodLink push notifications are working.",
      link: "/profile",
    })
      .catch((pushError) => {
        console.error("Failed to send test push notification:", pushError);
      });

    res.status(201).json({
      message: "Test notification created",
      notification: notification.toObject(),
    });
  } catch (error: any) {
    res.status(500).json({
      message: "Failed to send test push",
      error: error.message,
    });
  }
});

router.get("/", verifyToken, async (req: any, res) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit) || 20, 1), 100);
    const before = req.query.before ? new Date(String(req.query.before)) : null;
    if (before && Number.isNaN(before.getTime())) {
      return res.status(400).json({ message: "Invalid before cursor" });
    }
    const filter: Record<string, unknown> = { user: req.user.id };
    if (before) filter.createdAt = { $lt: before };
    const notifications = await Notification.find(filter)
      .sort({ createdAt: -1, _id: -1 })
      .limit(limit + 1);
    const hasMore = notifications.length > limit;
    const items = hasMore ? notifications.slice(0, limit) : notifications;
    res.json({
      items,
      hasMore,
      nextCursor: hasMore
        ? items[items.length - 1]?.createdAt?.toISOString() ?? null
        : null,
    });
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

router.put("/read-all", verifyToken, async (req: any, res) => {
  try {
    await Notification.updateMany(
      { user: req.user.id, read: false },
      { $set: { read: true } },
    );
    res.json({ message: "Notifications marked as read" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

router.put("/:id/read", verifyToken, async (req: any, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, user: req.user.id },
      { read: true },
      { new: true },
    );
    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }
    res.json(notification);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

export default router;

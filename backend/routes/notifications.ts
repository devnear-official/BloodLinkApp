import express from "express";
import Notification from "../models/Notification.ts";
import User from "../models/User.ts";
import { verifyToken } from "../middleware/auth.ts";
import { getPublicKey } from "../utils/webpush.ts";
import { sendPushNotification } from "../utils/firebaseAdmin.ts";

const router = express.Router();

// Get VAPID public key
router.get("/vapid-public-key", (req, res) => {
  const key = getPublicKey();
  res.json({ publicKey: key });
});

// Test push notification
router.post("/test-push", verifyToken, async (req: any, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    // Send via Firebase
    if (user.pushSubscriptions && user.pushSubscriptions.length > 0) {
      await sendPushNotification({
        pushSubscriptions: user.pushSubscriptions,
        save: () => user.save()
      }, {
        title: "Test Notification",
        message: "This is a test push notification from BloodLink!",
        link: "/profile"
      });
    }

    // Also emit via Socket.IO
    // const io = req.app.get("io");
    // if (io) {
    //   io.to(user._id.toString()).emit("notification", {
    //     _id: "test-" + Date.now(),
    //     message: "This is a test real-time notification!",
    //     type: "Test",
    //     link: "/profile",
    //     createdAt: new Date(),
    //     read: false
    //   });
    // }

    res.json({ message: "Test notifications initiated (FCM tokens: " + (user.pushSubscriptions?.length || 0) + ")" });
  } catch (error: any) {
    res.status(500).json({ message: "Failed to send test notification", error: error.message });
  }
});

// Subscribe to push notifications
router.post("/subscribe", verifyToken, async (req: any, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ message: "Token missing" });

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (!user.pushSubscriptions) {
      user.pushSubscriptions = [];
    }

    if (!user.pushSubscriptions.includes(token)) {
      user.pushSubscriptions.push(token);
      await user.save();
    }

    res.status(201).json({ message: "Subscribed successfully" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Get user notifications
router.get("/", verifyToken, async (req: any, res) => {
  try {
    const notifications = await Notification.find({ user: req.user.id })
      .sort({ createdAt: -1 })
      .limit(20);
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Mark all notifications as read
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

// Mark as read
router.put("/:id/read", verifyToken, async (req: any, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, user: req.user.id },
      { read: true },
      { new: true }
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

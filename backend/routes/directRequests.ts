import express from "express";
import DirectRequest from "../models/DirectRequest.ts";
import Notification from "../models/Notification.ts";
import User from "../models/User.ts";
import { verifyToken } from "../middleware/auth.ts";
import { checkEligibility } from "../utils/eligibility.ts";
import { sendMobilePushNotification } from "../utils/oneSignal.ts";

const router = express.Router();

// Get direct requests for user (as donor or requester)
router.get("/", verifyToken, async (req: any, res) => {
  try {
    const userId = req.user.id;
    const type = req.query.type || req.query.box; // 'received' or 'sent'
    
    if (type === 'received') {
      const requests = await DirectRequest.find({ donor: userId })
        .populate('requester', 'name phone bloodGroup')
        .populate('donor', 'name phone bloodGroup')
        .sort({ createdAt: -1 });
      res.json(requests);
    } else {
      const requests = await DirectRequest.find({ requester: userId })
        .populate('donor', 'name phone bloodGroup')
        .populate('requester', 'name phone bloodGroup')
        .sort({ createdAt: -1 });
      res.json(requests);
    }
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Create a new direct request
router.post("/", verifyToken, async (req: any, res) => {
  try {
    const {
      donorId,
      contactInfo,
      bloodGroup,
      hospitalName,
      contactNumber,
      requiredDate,
      message,
    } = req.body;
    const requesterId = req.user.id;
    if (!donorId) {
      return res.status(400).json({ message: "A donor is required" });
    }
    if (donorId === requesterId) {
      return res.status(400).json({ message: "You cannot request yourself" });
    }
    
    // Check if donor is eligible to receive requests
    const donorUser = await User.findById(donorId);
    if (!donorUser) {
      return res.status(404).json({ message: "Donor not found" });
    }
    if (!checkEligibility(donorUser)) {
      return res.status(400).json({ message: "This donor is currently not eligible to donate." });
    }

    const request = new DirectRequest({
      requester: requesterId,
      donor: donorId,
      bloodGroup: bloodGroup || donorUser.bloodGroup,
      hospitalName,
      contactNumber,
      requiredDate,
      contactInfo,
      message
    });
    
    await request.save();

    // Create a notification for the donor
    const notification = new Notification({
      user: donorId,
      title: 'New direct request',
      message: `Someone requested you for blood donation!`,
      type: 'DirectRequest',
      link: '/profile?tab=received'
    });
    await notification.save();

    const populatedRequest = await DirectRequest.findById(request._id)
      .populate('requester', 'name phone bloodGroup')
      .populate('donor', 'name phone bloodGroup');

    // Emit socket event if user is connected
    const io = req.app.get("io");
    if (io) {
      const notificationData = notification.toObject();
      io.to(donorId).emit("notification:new", notificationData);
      io.to(donorId).emit("notification", notificationData);
      io.to(donorId).emit("direct_request:new", populatedRequest);
      io.to(donorId).emit("new-direct-request", populatedRequest);
    }
    
    const donorUserForPush = await User.findById(donorId);
    if (donorUserForPush) {
      try {
        await sendMobilePushNotification(donorUserForPush._id.toString(), {
          title: 'Blood Link: Direct Request',
          message: `Someone directly requested you for a blood donation!`,
          link: '/profile?tab=received',
        });
      } catch (pushError) {
        console.error("Failed to send direct-request push notification:", pushError);
      }
    }

    res.status(201).json(populatedRequest);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Update request status (Accept/Decline)
router.put("/:id/status", verifyToken, async (req: any, res) => {
  try {
    const { status } = req.body;
    if (!['Accepted', 'Declined'].includes(status)) {
      return res.status(400).json({ message: "Invalid status value" });
    }
    const request = await DirectRequest.findById(req.params.id).populate('requester donor');
    
    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    // Only the donor can accept/decline
    if (request.donor._id.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (status === 'Accepted') {
      const donorUser = await User.findById(req.user.id);
      if (!donorUser || !checkEligibility(donorUser)) {
        return res.status(400).json({ message: "You are not eligible to donate right now." });
      }
    }

    request.status = status;
    await request.save();

    // Send Notification back to requester
    const notification = new Notification({
      user: request.requester._id,
      title: `Direct request ${status.toLowerCase()}`,
      message: `Your direct blood request was ${status} by ${(request.donor as any).name}!`,
      type: 'StatusUpdate',
      link: '/profile?tab=sent'
    });
    await notification.save();

    // Emit socket event
    const populatedRequest = await DirectRequest.findById(request._id)
      .populate('requester', 'name phone bloodGroup')
      .populate('donor', 'name phone bloodGroup');
    const io = req.app.get("io");
    if (io) {
      const notificationData = notification.toObject();
      io.to(request.requester._id.toString()).emit("notification:new", notificationData);
      io.to(request.requester._id.toString()).emit("notification", notificationData);
      io.to(request.requester._id.toString()).emit("direct_request:updated", populatedRequest);
      io.to(request.requester._id.toString()).emit("direct-request-updated", populatedRequest);
    }
    
    const requesterUserForPush = await User.findById(request.requester._id.toString());
    if (requesterUserForPush) {
      try {
        await sendMobilePushNotification(
          requesterUserForPush._id.toString(),
          {
          title: 'Blood Link: Request ' + status,
          message: `Your direct blood request was ${status} by ${(request.donor as any).name}!`,
          link: '/profile?tab=sent',
          },
        );
      } catch (pushError) {
        console.error("Failed to send direct-request update push notification:", pushError);
      }
    }

    res.json(populatedRequest);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Delete (Cancel) direct request
router.delete("/:id", verifyToken, async (req: any, res) => {
  try {
    const request = await DirectRequest.findById(req.params.id);
    
    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    // Only the requester can cancel their request
    if (request.requester.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized to cancel this request" });
    }
    
    if (request.status !== 'Pending') {
      return res.status(400).json({ message: "Cannot cancel a request that is already processed" });
    }

    await DirectRequest.findByIdAndDelete(req.params.id);

    // Send Notification back to donor
    const notification = new Notification({
      user: request.donor,
      title: 'Direct request cancelled',
      message: `A direct blood request sent to you was cancelled by the requester.`,
      type: 'StatusUpdate',
      link: '/profile?tab=received'
    });
    await notification.save();

    // Emit socket event
    const io = req.app.get("io");
    if (io) {
      const notificationData = notification.toObject();
      io.to(request.donor.toString()).emit("notification:new", notificationData);
      io.to(request.donor.toString()).emit("notification", notificationData);
      io.to(request.donor.toString()).emit("direct_request:cancelled", req.params.id);
      io.to(request.donor.toString()).emit("direct-request-cancelled", req.params.id);
    }
    
    const donorToNotifyPush = await User.findById(request.donor.toString());
    if (donorToNotifyPush) {
      try {
        await sendMobilePushNotification(
          donorToNotifyPush._id.toString(),
          {
          title: 'Blood Link: Request Cancelled',
          message: 'A direct blood request sent to you was cancelled.',
          link: '/profile?tab=received',
          },
        );
      } catch (pushError) {
        console.error("Failed to send cancellation push notification:", pushError);
      }
    }

    res.json({ message: "Request cancelled successfully" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

export default router;

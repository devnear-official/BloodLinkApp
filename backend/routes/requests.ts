import express from "express";
import BloodRequest from "../models/BloodRequest.ts";
import Notification from "../models/Notification.ts";
import User from "../models/User.ts";
import { verifyToken } from "../middleware/auth.ts";
import { checkEligibility } from "../utils/eligibility.ts";
import { sendMobilePushNotification } from "../utils/oneSignal.ts";

const router = express.Router();

// Get requests, optionally filtered by the public feed selectors.
router.get("/", async (req, res) => {
  try {
    const filter: Record<string, unknown> = {};
    for (const key of ["bloodGroup", "division", "district", "status"]) {
      const value = req.query[key];
      if (typeof value === "string" && value.length > 0) {
        filter[key] = key === "bloodGroup" ? value.toUpperCase() : value;
      }
    }
    const query = BloodRequest.find(filter)
      .populate("createdBy", "name email phone")
      .populate("acceptedBy", "name phone")
      .populate("donorResponses.donor", "name phone bloodGroup")
      .sort({ createdAt: -1 });
    if (req.query.page !== undefined) {
      const page = Math.max(Number.parseInt(String(req.query.page), 10) || 1, 1);
      const limit = Math.min(
        Math.max(Number.parseInt(String(req.query.limit), 10) || 20, 1),
        50,
      );
      const [items, total] = await Promise.all([
        query.clone().skip((page - 1) * limit).limit(limit).lean(),
        BloodRequest.countDocuments(filter),
      ]);
      return res.json({
        items,
        page,
        limit,
        total,
        hasMore: page * limit < total,
      });
    }
    const requests = await query;
    res.json(requests);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Create a new request for the authenticated user.
router.post("/", verifyToken, async (req: any, res) => {
  try {
    const {
      patientName,
      bloodGroup,
      hospitalName,
      contactNumber,
      division,
      district,
      upazila,
      requiredDate,
      message,
      priority,
    } = req.body;
    
    const newRequest = new BloodRequest({
      patientName,
      bloodGroup,
      hospitalName,
      contactNumber,
      division,
      district,
      upazila,
      requiredDate,
      message,
      priority,
      createdBy: req.user.id,
    });

    await newRequest.save();
    
    // Populate createdBy before emitting so the frontend gets the full object
    await newRequest.populate("createdBy", "name email");
    
    const io = req.app.get("io");
    if (io) {
      const requestData = newRequest.toObject();
      io.emit("request:created", requestData);
      io.emit("new-blood-request", requestData);
    }

    // --- NEW: Broadcast Notification to users (filtering by blood group compatibility if wanted, but for now all users) ---
    try {
      // Find all users except the creator who have push subscriptions or need a notification doc
      const targetUsers = await User.find({ _id: { $ne: req.user.id } });
      
      if (targetUsers.length > 0) {
        // 1. Create notification documents in bulk
        const notificationDocs = targetUsers.map(u => ({
          user: u._id,
          title: "New blood request",
          message: `${patientName} needs urgent ${bloodGroup} blood at ${hospitalName}, ${upazila}.`,
          type: 'NewRequest',
          link: `/request-blood?highlight=${newRequest._id}`,
          read: false,
          createdAt: new Date()
        }));
        
        const insertedNotifications = await Notification.insertMany(notificationDocs);
        
        // 2. Emit via Socket.IO to connected users
        const io = req.app.get("io");
        if (io) {
          insertedNotifications.forEach(notif => {
            const notificationData = notif.toObject();
            io.to(notif.user.toString()).emit("notification:new", notificationData);
            io.to(notif.user.toString()).emit("notification", notificationData);
          });
        }
        
        // 3. Send push notifications without allowing delivery errors to undo the request.
        try {
          await sendMobilePushNotification(
            targetUsers.map((user) => user._id.toString()),
            {
              title: "Blood Link: New Urgent Request",
              message: `${patientName} needs urgent ${bloodGroup} blood at ${hospitalName}, ${upazila}.`,
              link: `/request-blood?highlight=${newRequest._id}`,
            },
          );
        } catch (pushError) {
          console.error("Failed to send blood-request push notification:", pushError);
        }
      }
    } catch (notifErr) {
      console.error("Failed to broadcast notifications:", notifErr);
    }
    
    res.status(201).json(newRequest);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Donor responds to a blood request
router.post("/:id/respond", verifyToken, async (req: any, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id)
      .populate('createdBy', 'name')
      .populate('donorResponses.donor', 'name phone bloodGroup');
    
    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    if (request.status !== "Active") {
      return res.status(400).json({ message: "Request is no longer active" });
    }

    if (request.createdBy._id.toString() === req.user.id) {
      return res.status(400).json({ message: "You cannot respond to your own request" });
    }

    const donorUser = await User.findById(req.user.id);
    if (!donorUser || !checkEligibility(donorUser)) {
      return res.status(400).json({ message: "You are not eligible to donate right now." });
    }

    const alreadyResponded = request.donorResponses.some((r: any) => r.donor._id.toString() === req.user.id || r.donor.toString() === req.user.id);
    if (alreadyResponded) {
      return res.status(400).json({ message: "You have already responded to this request" });
    }

    request.donorResponses.push({
      donor: req.user.id,
      status: "Pending",
      createdAt: new Date()
    });

    await request.save();
    await request.populate("donorResponses.donor", "name phone bloodGroup");

    // Send a notification to the creator
    const notification = new Notification({
      user: request.createdBy._id,
      title: 'A donor responded to your request',
      message: `${donorUser.name || 'A donor'} has offered to donate blood for ${request.patientName}! Review their response.`,
      type: 'DonorResponse',
      link: `/request-blood?highlight=${request._id}`
    });
    await notification.save();

    const io = req.app.get("io");
    if (io) {
      const notificationData = notification.toObject();
      io.to(request.createdBy._id.toString()).emit("notification:new", notificationData);
      io.to(request.createdBy._id.toString()).emit("notification", notificationData);
      const requestData = request.toObject();
      io.emit("request:updated", requestData);
      io.emit("blood-request-updated", requestData);
    }
    
    const creatorUserToPush = await User.findById(request.createdBy._id.toString());
    if (creatorUserToPush) {
      try {
        await sendMobilePushNotification(creatorUserToPush._id.toString(), {
          title: 'Blood Link: Donor Responded',
          message: `${donorUser.name || 'A donor'} has offered to donate blood for ${request.patientName}! review their response.`,
          link: `/request-blood?highlight=${request._id}`
        });
      } catch (pushError) {
        console.error("Failed to send donor-response push notification:", pushError);
      }
    }

    res.json(request);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Creator accepts or rejects a donor's response
router.put("/:id/responses/:donorId/status", verifyToken, async (req: any, res) => {
  try {
    const { status } = req.body;
    if (!['Accepted', 'Rejected'].includes(status)) {
      return res.status(400).json({ message: "Invalid status value" });
    }

    const request = await BloodRequest.findById(req.params.id)
      .populate('createdBy', 'name')
      .populate('acceptedBy', 'name phone')
      .populate('donorResponses.donor', 'name phone bloodGroup');

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    if (request.createdBy._id.toString() !== req.user.id) {
      return res.status(403).json({ message: "Only the request creator can review responses" });
    }

    const responseIndex = request.donorResponses.findIndex((r: any) => 
      (r.donor && r.donor._id && r.donor._id.toString() === req.params.donorId) || 
      (r.donor && typeof r.donor === 'string' && r.donor === req.params.donorId) ||
      (r.donor && r.donor._id && typeof r.donor._id === 'string' && r.donor._id === req.params.donorId)
    );
    if (responseIndex === -1) {
      return res.status(404).json({ message: "Donor response not found" });
    }

    if (status === 'Accepted') {
      if (request.status === 'Accepted' && request.acceptedBy?._id?.toString() !== req.params.donorId && request.acceptedBy?.toString() !== req.params.donorId) {
        return res.status(400).json({ message: "Another donor is already accepted for this request" });
      }
      
      request.donorResponses[responseIndex].status = 'Accepted';
      request.status = 'Accepted';
      request.acceptedBy = request.donorResponses[responseIndex].donor._id || req.params.donorId;
    } else {
       // Rejected
       request.donorResponses[responseIndex].status = 'Rejected';
       // If rejecting a previously accepted donor (backing out), revert main status to Active
       if (request.acceptedBy?._id?.toString() === req.params.donorId || request.acceptedBy?.toString() === req.params.donorId) {
         request.status = 'Active';
         request.acceptedBy = undefined;
       }
    }

    await request.save();
    
    // Repopulate explicitly as assigning ID wipes populated document locally
    if (status === 'Accepted') {
      await request.populate('acceptedBy', 'name phone');
    }
    await request.populate('donorResponses.donor', 'name phone bloodGroup');

    // Send a notification to the assigned donor
    const notification = new Notification({
      user: req.params.donorId,
      title: `Your donation offer was ${status.toLowerCase()}`,
      message: `Your offer to donate blood for ${request.patientName} was ${status.toLowerCase()} by the requester.`,
      type: 'ResponseReviewed',
      link: `/request-blood?highlight=${request._id}`
    });
    await notification.save();

    const io = req.app.get("io");
    if (io) {
      const notificationData = notification.toObject();
      io.to(req.params.donorId).emit("notification:new", notificationData);
      io.to(req.params.donorId).emit("notification", notificationData);
      const requestData = request.toObject();
      io.emit("request:updated", requestData);
      io.emit("blood-request-updated", requestData);
    }
    
    const donorUser = await User.findById(req.params.donorId);
    if (donorUser) {
      try {
        await sendMobilePushNotification(donorUser._id.toString(), {
          title: 'Blood Link: Offer ' + status,
          message: `Your offer to donate for ${request.patientName} was ${status.toLowerCase()}.`,
          link: `/request-blood?highlight=${request._id}`
        });
      } catch (pushError) {
        console.error("Failed to send offer-status push notification:", pushError);
      }
    }

    res.json(request);
  } catch (error) {
    console.error("Error confirming response:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

// Update request status (creator or admin only).
router.put("/:id/status", verifyToken, async (req: any, res) => {
  try {
    const { status } = req.body;
    const allowedStatuses = ["Active", "Accepted", "Fulfilled", "Cancelled"];
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status value" });
    }
    const request = await BloodRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ message: "Request not found" });
    const user = await User.findById(req.user.id).select("role");
    if (
      request.createdBy.toString() !== req.user.id &&
      user?.role !== "Admin"
    ) {
      return res.status(403).json({ message: "Not authorized to update this request" });
    }
    request.status = status;
    await request.save();
    await request.populate([
      { path: "createdBy", select: "name email phone" },
      { path: "acceptedBy", select: "name phone" },
      { path: "donorResponses.donor", select: "name phone bloodGroup" },
    ]);
    const io = req.app.get("io");
    if (io) {
      const requestData = request.toObject();
      io.emit("request:updated", requestData);
      io.emit("blood-request-updated", requestData);
    }
    res.json(request);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Update request priority (creator or admin only).
router.put("/:id/priority", verifyToken, async (req: any, res) => {
  try {
    const { priority } = req.body;
    const allowedPriorities = ["Low", "Medium", "High", "Critical"];
    if (!allowedPriorities.includes(priority)) {
      return res.status(400).json({ message: "Invalid priority value" });
    }
    const request = await BloodRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ message: "Request not found" });
    const user = await User.findById(req.user.id).select("role");
    if (
      request.createdBy.toString() !== req.user.id &&
      user?.role !== "Admin"
    ) {
      return res.status(403).json({ message: "Not authorized to update this request" });
    }
    request.priority = priority;
    await request.save();
    await request.populate([
      { path: "createdBy", select: "name email phone" },
      { path: "acceptedBy", select: "name phone" },
      { path: "donorResponses.donor", select: "name phone bloodGroup" },
    ]);
    const io = req.app.get("io");
    if (io) {
      const requestData = request.toObject();
      io.emit("request:updated", requestData);
      io.emit("blood-request-updated", requestData);
    }
    res.json(request);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Delete a request
router.delete("/:id", verifyToken, async (req: any, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id).populate('donorResponses.donor', '_id');
    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }
    const dbUser = await User.findById(req.user.id);
    
    if (request.createdBy.toString() !== req.user.id && dbUser?.role !== 'Admin') {
      return res.status(403).json({ message: "Not authorized to delete this request" });
    }
    
    await BloodRequest.findByIdAndDelete(req.params.id);

    // Notify donors who responded
    const io = req.app.get("io");
    if (request.donorResponses && request.donorResponses.length > 0) {
      for (const response of request.donorResponses) {
        const donorId = response.donor._id?.toString() || response.donor.toString();
        
        const notification = new Notification({
          user: donorId,
          title: "Blood request cancelled",
          message: `The blood request for ${request.patientName} has been cancelled by the creator.`,
          type: 'RequestCancelled',
          link: '/request-blood',
          read: false,
        });
        await notification.save();
        
        if (io) {
          const notificationData = notification.toObject();
          io.to(donorId).emit("notification:new", notificationData);
          io.to(donorId).emit("notification", notificationData);
        }
        
        const donorUserForPush = await User.findById(donorId);
        if (donorUserForPush) {
          try {
            await sendMobilePushNotification(donorUserForPush._id.toString(), {
              title: 'Blood Link: Request Cancelled',
              message: `The request for ${request.patientName} was cancelled.`,
              link: `/request-blood?highlight=${request._id}`
            });
          } catch (pushError) {
            console.error("Failed to send request-cancellation push notification:", pushError);
          }
        }
      }
    }
    
    if (io) {
      io.emit("request:deleted", { id: req.params.id });
      io.emit("blood-request-deleted", req.params.id);
    }
    
    res.json({ message: "Request deleted" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

export default router;

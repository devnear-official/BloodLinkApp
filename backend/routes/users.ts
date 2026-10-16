import express from "express";
import { v2 as cloudinary } from "cloudinary";
import multer from "multer";
import { Readable } from "node:stream";
import User from "../models/User.ts";
import { verifyToken } from "../middleware/auth.ts";

const router = express.Router();
const safeUserProjection =
  "-password -location -pushSubscriptions -webPushSubscriptions -emailVerificationCodeHash -passwordResetCodeHash";
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.mimetype)) {
      callback(new Error("Choose a JPEG, PNG, or WebP image"));
      return;
    }
    callback(null, true);
  },
});

function uploadProfileImage(buffer: Buffer): Promise<{ secure_url: string }> {
  const { CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET } =
    process.env;
  if (!CLOUDINARY_CLOUD_NAME || !CLOUDINARY_API_KEY || !CLOUDINARY_API_SECRET) {
    throw new Error("Profile photo storage is not configured");
  }
  cloudinary.config({
    cloud_name: CLOUDINARY_CLOUD_NAME,
    api_key: CLOUDINARY_API_KEY,
    api_secret: CLOUDINARY_API_SECRET,
  });
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: "bloodlink/profiles", resource_type: "image" },
      (error, result) => {
        if (error || !result) {
          reject(error ?? new Error("Image upload returned no result"));
          return;
        }
        resolve(result);
      },
    );
    Readable.from(buffer).pipe(stream);
  });
}

router.post(
  "/me/photo",
  verifyToken,
  (req, res, next) => {
    upload.single("photo")(req, res, (error) => {
      if (error) {
        return res.status(400).json({
          message: error.message || "Could not process the uploaded image",
        });
      }
      next();
    });
  },
  async (req: any, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: "A profile photo is required" });
      }
      if (
        !process.env.CLOUDINARY_CLOUD_NAME ||
        !process.env.CLOUDINARY_API_KEY ||
        !process.env.CLOUDINARY_API_SECRET
      ) {
        return res
          .status(503)
          .json({ message: "Profile photo storage is not configured" });
      }
      const result = await uploadProfileImage(req.file.buffer);
      const user = await User.findByIdAndUpdate(
        req.user.id,
        { $set: { picture: result.secure_url } },
        { new: true },
      ).select(safeUserProjection);
      if (!user) return res.status(404).json({ message: "User not found" });
      res.json(user);
    } catch (error) {
      console.error("Profile photo upload failed:", error);
      res.status(500).json({ message: "Profile photo upload failed" });
    }
  },
);

router.get("/nearby", verifyToken, async (req: any, res) => {
  try {
    const latitude = Number(req.query.latitude);
    const longitude = Number(req.query.longitude);
    const radiusKm = Number(req.query.radiusKm ?? 25);
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 100);
    if (
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90 ||
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180 ||
      !Number.isFinite(radiusKm) ||
      radiusKm <= 0 ||
      radiusKm > 100
    ) {
      return res
        .status(400)
        .json({ message: "Invalid nearby search coordinates or radius" });
    }

    await User.updateOne(
      { _id: req.user.id },
      {
        $set: {
          location: { type: "Point", coordinates: [longitude, latitude] },
          lastLocationUpdatedAt: new Date(),
        },
      },
    );
    const donors = await User.find({
      _id: { $ne: req.user.id },
      status: "Available",
      role: { $ne: "Admin" },
      location: {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [longitude, latitude],
          },
          $maxDistance: radiusKm * 1000,
        },
      },
    })
      .select(
      "-password -email -phone -address -medicalConditions -pushSubscriptions -webPushSubscriptions -emailVerificationCodeHash -passwordResetCodeHash",
      )
      .limit(limit)
      .lean();

    const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
    const items = donors.map((donor) => {
      const [donorLongitude, donorLatitude] =
        donor.location?.coordinates ?? [longitude, latitude];
      const deltaLatitude = toRadians(donorLatitude - latitude);
      const deltaLongitude = toRadians(donorLongitude - longitude);
      const a =
        Math.sin(deltaLatitude / 2) ** 2 +
        Math.cos(toRadians(latitude)) *
          Math.cos(toRadians(donorLatitude)) *
          Math.sin(deltaLongitude / 2) ** 2;
      const distanceKm = 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      const { location: _location, ...publicDonor } = donor;
      return { ...publicDonor, distanceKm: Math.round(distanceKm * 10) / 10 };
    });

    res.json(items);
  } catch (error) {
    console.error("Nearby donor search failed:", error);
    res.status(500).json({ message: "Nearby donor search failed" });
  }
});

// Get current user
router.get("/me", verifyToken, async (req: any, res: any) => {
  try {
    const user = await User.findById(req.user.id).select(safeUserProjection);
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Update only profile fields; account roles and credentials are not editable here.
router.put("/me", verifyToken, async (req: any, res: any) => {
  try {
    const editableFields = [
      "name",
      "phone",
      "bloodGroup",
      "division",
      "district",
      "upazila",
      "lastDonation",
      "status",
      "address",
      "medicalConditions",
    ];
    const updates = Object.fromEntries(
      editableFields
        .filter((field) => Object.hasOwn(req.body, field))
        .map((field) => [field, req.body[field]]),
    );
    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      { $set: updates },
      { new: true, runValidators: true },
    ).select(safeUserProjection);
    if (!updatedUser) return res.status(404).json({ message: "User not found" });
    res.json(updatedUser);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Get all users
router.get("/", verifyToken, async (req: any, res) => {
  try {
    const currentUser = await User.findById(req.user.id).select("role");
    if (!currentUser) return res.status(401).json({ message: "Unauthorized" });
    const isAdmin = currentUser.role.toLowerCase() === "admin";
    const filter: Record<string, unknown> = {};
    for (const key of ["division", "district", "upazila", "bloodGroup"]) {
      const value = req.query[key];
      if (typeof value === "string" && value.length > 0) {
        filter[key] = key === "bloodGroup" ? value.toUpperCase() : value;
      }
    }
    if (req.query.isAvailable === "true") filter.status = "Available";
    if (req.query.isAvailable === "false") filter.status = "Unavailable";
    const query = User.find(filter)
      .select(
        isAdmin
          ? safeUserProjection
          : `${safeUserProjection} -email -phone -address -medicalConditions`,
      )
      .sort({ createdAt: -1 });
    if (req.query.page !== undefined) {
      const page = Math.max(Number.parseInt(String(req.query.page), 10) || 1, 1);
      const limit = Math.min(
        Math.max(Number.parseInt(String(req.query.limit), 10) || 20, 1),
        50,
      );
      const [items, total] = await Promise.all([
        query.clone().skip((page - 1) * limit).limit(limit).lean(),
        User.countDocuments(filter),
      ]);
      return res.json({
        items,
        page,
        limit,
        total,
        hasMore: page * limit < total,
      });
    }
    const users = await query;
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

const requireAdmin = async (req: any, res: any, next: any) => {
  try {
    const user = await User.findById(req.user.id).select("role");
    if (!user || user.role.toLowerCase() !== "admin") {
      return res.status(403).json({ message: "Admin access required" });
    }
    next();
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
};

// Update user status
router.put("/:id/status", verifyToken, requireAdmin, async (req, res) => {
  try {
    const { status } = req.body;
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true },
    ).select(safeUserProjection);
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Update user role
router.put("/:id/role", verifyToken, requireAdmin, async (req, res) => {
  try {
    const { role } = req.body;
    if (!["Admin", "User"].includes(role)) {
      return res.status(400).json({ message: "Invalid role value" });
    }
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { role },
      { new: true },
    ).select(safeUserProjection);
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Delete a user
router.delete("/:id", verifyToken, requireAdmin, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: "User deleted" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

export default router;

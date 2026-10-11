import express from "express";
import User from "../models/User.ts";
import { verifyToken } from "../middleware/auth.ts";

const router = express.Router();
// Get current user
router.get("/me", verifyToken, async (req: any, res: any) => {
  try {
    const user = await User.findById(req.user.id).select("-password");
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
    ).select("-password");
    if (!updatedUser) return res.status(404).json({ message: "User not found" });
    res.json(updatedUser);
  } catch (error) {
    res.status(500).json({ message: "Server error", error });
  }
});

// Get all users
router.get("/", async (req, res) => {
  try {
    const filter: Record<string, unknown> = {};
    for (const key of ["division", "district", "upazila", "bloodGroup"]) {
      const value = req.query[key];
      if (typeof value === "string" && value.length > 0) {
        filter[key] = key === "bloodGroup" ? value.toUpperCase() : value;
      }
    }
    if (req.query.isAvailable === "true") filter.status = "Available";
    if (req.query.isAvailable === "false") filter.status = "Unavailable";
    const users = await User.find(filter)
      .select("-password -pushSubscriptions")
      .sort({ createdAt: -1 });
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
    const user = await User.findByIdAndUpdate(req.params.id, { status }, { new: true }).select("-password");
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
    const user = await User.findByIdAndUpdate(req.params.id, { role }, { new: true }).select("-password");
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

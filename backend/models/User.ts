import mongoose from "mongoose";

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: false },
  googleId: { type: String, required: false },
  emailVerified: { type: Boolean, default: true },
  emailVerificationCodeHash: { type: String },
  emailVerificationExpiresAt: { type: Date },
  emailVerificationSentAt: { type: Date },
  passwordResetCodeHash: { type: String },
  passwordResetExpiresAt: { type: Date },
  passwordResetSentAt: { type: Date },
  picture: { type: String, required: false },
  studentId: { type: String, required: false },
  department: { type: String },
  batch: { type: String },
  dob: { type: String },
  bloodGroup: { type: String, required: false },
  phone: { type: String },
  division: { type: String },
  district: { type: String },
  upazila: { type: String },
  location: {
    type: { type: String, enum: ["Point"] },
    coordinates: { type: [Number] },
  },
  lastLocationUpdatedAt: { type: Date },
  address: { type: String },
  medicalConditions: { type: String },
  lastDonation: { type: String },
  status: { type: String, default: "Available" },
  role: { type: String, default: "User" },
  pushSubscriptions: { type: Array, default: [] },
  webPushSubscriptions: { type: Array, default: [] },
  createdAt: { type: Date, default: Date.now }
});

userSchema.index({ location: "2dsphere" });

export default mongoose.model("User", userSchema);

import mongoose from "mongoose";

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: false },
  googleId: { type: String, required: false },
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
  address: { type: String },
  medicalConditions: { type: String },
  lastDonation: { type: String },
  status: { type: String, default: "Available" },
  role: { type: String, default: "User" },
  pushSubscriptions: { type: Array, default: [] },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model("User", userSchema);

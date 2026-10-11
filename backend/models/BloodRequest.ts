import mongoose from "mongoose";

const bloodRequestSchema = new mongoose.Schema({
  patientName: { type: String, required: true },
  bloodGroup: { type: String, required: true },
  hospitalName: { type: String, required: true },
  contactNumber: { type: String, required: true },
  division: { type: String, required: true },
  district: { type: String, required: true },
  upazila: { type: String, required: true },
  requiredDate: { type: String, required: true },
  message: { type: String },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  acceptedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  donorResponses: [{
    donor: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    status: { type: String, enum: ["Pending", "Accepted", "Rejected"], default: "Pending" },
    createdAt: { type: Date, default: Date.now }
  }],
  status: { type: String, default: "Active" },
  priority: { type: String, default: "Medium" },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model("BloodRequest", bloodRequestSchema);

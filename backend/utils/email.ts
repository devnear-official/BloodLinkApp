import { createHash, randomInt, timingSafeEqual } from "node:crypto";
import nodemailer from "nodemailer";

export function createEmailCode() {
  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  return { code, hash: hashEmailCode(code) };
}

export function hashEmailCode(code: string) {
  return createHash("sha256").update(code).digest("hex");
}

export function matchesEmailCode(code: string, hash: string) {
  const expected = Buffer.from(hashEmailCode(code), "hex");
  const actual = Buffer.from(hash, "hex");
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export async function sendEmailCode(
  email: string,
  subject: string,
  code: string,
  purpose: "verification" | "password reset",
) {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM;
  if (!host || !user || !pass || !from) {
    throw new Error("Email delivery is not configured");
  }

  const transporter = nodemailer.createTransport({
    host,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === "true",
    auth: { user, pass },
  });
  await transporter.sendMail({
    from,
    to: email,
    subject,
    text: `Your BloodLink ${purpose} code is ${code}. It expires in 10 minutes.`,
  });
}

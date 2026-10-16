import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User.ts';
import { OAuth2Client } from 'google-auth-library';
import {
  createEmailCode,
  matchesEmailCode,
  sendEmailCode,
} from '../utils/email.ts';
import { JWT_SECRET } from '../config/auth.ts';

const router = express.Router();
const GOOGLE_CLIENT_ID =
  process.env.VITE_GOOGLE_CLIENT_ID ||
  '426841026024-78am0akqjms589mpq4brgmrh2g7lfggg.apps.googleusercontent.com';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

router.post('/google', async (req, res) => {
  try {
    const token = req.body.idToken ?? req.body.token;
    if (typeof token !== 'string' || token.length === 0) {
      return res.status(400).json({ message: 'Google ID token is required' });
    }
    const ticket = await googleClient.verifyIdToken({
      idToken: token,
      audience: GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload)
      return res.status(400).json({ message: 'Invalid Google token' });

    const { sub: googleId, name, picture } = payload;
    const email = payload.email?.toLowerCase();
    if (!email || payload.email_verified !== true) {
      return res.status(403).json({ message: 'Google email is not verified' });
    }

    let user = await User.findOne({ email });

    if (!user) {
      // Create new user if they don't exist yet
      user = new User({
        name,
        email,
        googleId,
        picture,
        role: 'User',
        status: 'Available',
      });
      await user.save();
    } else {
      // Update existing user with google info if needed
      user.googleId = googleId;
      user.emailVerified = true;
      if (picture && !user.picture) user.picture = picture;
      await user.save();
    }

    const authToken = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, {
      expiresIn: '1d',
    });

    res.json({
      token: authToken,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        bloodGroup: user.bloodGroup,
        division: user.division,
        district: user.district,
        upazila: user.upazila,
        status: user.status,
        role: user.role,
        picture: user.picture,
        emailVerified: true,
      },
    });
  } catch (error) {
    console.error('Google login error:', error);
    res.status(500).json({ message: 'Server error', error });
  }
});

router.post('/register', async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      studentId,
      department,
      batch,
      dob,
      bloodGroup,
      phone,
      division,
      district,
      upazila,
    } = req.body;

    if (
      typeof name !== 'string' ||
      !name.trim() ||
      typeof email !== 'string' ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      typeof password !== 'string' ||
      password.length < 6
    ) {
      return res.status(400).json({
        message: 'Name, valid email, and a password of at least 6 characters are required.',
      });
    }
    const normalizedEmail = email.trim().toLowerCase();

    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res
        .status(400)
        .json({ message: 'User already exists with that email.' });
    }

    if (studentId) {
      const existingStudentId = await User.findOne({ studentId });
      if (existingStudentId) {
        return res
          .status(400)
          .json({ message: 'Student ID is already registered.' });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const verification = createEmailCode();
    const user = new User({
      name,
      email: normalizedEmail,
      emailVerified: false,
      emailVerificationCodeHash: verification.hash,
      emailVerificationExpiresAt: new Date(Date.now() + 10 * 60 * 1000),
      emailVerificationSentAt: new Date(),
      password: hashedPassword,
      studentId,
      department,
      batch,
      dob,
      bloodGroup,
      phone,
      division,
      district,
      upazila,
    });

    await user.save();
    try {
      await sendEmailCode(
        normalizedEmail,
        'Verify your BloodLink account',
        verification.code,
        'verification',
      );
    } catch (error) {
      console.error('Registration verification email failed:', error);
      return res.status(503).json({
        message:
          'Your account was created, but verification email could not be sent. Use Resend verification from the login screen.',
      });
    }

    res.status(201).json({ message: 'Verification code sent' });
  } catch (error: any) {
    console.error('Registration server error:', error);
    res
      .status(500)
      .json({ message: 'Server error', error: error.message || error });
  }
});

router.post('/verify-email', async (req, res) => {
  try {
    const email =
      typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';
    if (!email || !/^\d{6}$/.test(code)) {
      return res.status(400).json({ message: 'Enter your email and 6-digit code' });
    }
    const user = await User.findOne({ email });
    if (
      !user ||
      user.emailVerified ||
      !user.emailVerificationCodeHash ||
      !user.emailVerificationExpiresAt ||
      user.emailVerificationExpiresAt.getTime() < Date.now() ||
      !matchesEmailCode(code, user.emailVerificationCodeHash)
    ) {
      return res.status(400).json({ message: 'Invalid or expired verification code' });
    }
    user.emailVerified = true;
    user.emailVerificationCodeHash = undefined;
    user.emailVerificationExpiresAt = undefined;
    user.emailVerificationSentAt = undefined;
    await user.save();
    res.json({ message: 'Email verified. You can now sign in.' });
  } catch (error) {
    res.status(500).json({ message: 'Email verification failed', error });
  }
});

router.post('/resend-verification', async (req, res) => {
  try {
    const email =
      typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    if (!email) return res.status(400).json({ message: 'Email is required' });
    const user = await User.findOne({ email });
    if (user && !user.emailVerified) {
      if (
        user.emailVerificationSentAt &&
        Date.now() - user.emailVerificationSentAt.getTime() < 60_000
      ) {
        return res.status(429).json({ message: 'Wait a minute before requesting another code' });
      }
      const verification = createEmailCode();
      user.emailVerificationCodeHash = verification.hash;
      user.emailVerificationExpiresAt = new Date(Date.now() + 10 * 60 * 1000);
      user.emailVerificationSentAt = new Date();
      await user.save();
      await sendEmailCode(
        email,
        'Verify your BloodLink account',
        verification.code,
        'verification',
      );
    }
    res.json({ message: 'If the account needs verification, a code has been sent.' });
  } catch (error) {
    console.error('Verification email resend failed:', error);
    res.status(503).json({ message: 'Email delivery is unavailable' });
  }
});

router.post('/forgot-password', async (req, res) => {
  try {
    const email =
      typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    if (!email) return res.status(400).json({ message: 'Email is required' });
    const user = await User.findOne({ email, password: { $exists: true } });
    if (user) {
      if (
        user.passwordResetSentAt &&
        Date.now() - user.passwordResetSentAt.getTime() < 60_000
      ) {
        return res.status(429).json({ message: 'Wait a minute before requesting another code' });
      }
      const reset = createEmailCode();
      user.passwordResetCodeHash = reset.hash;
      user.passwordResetExpiresAt = new Date(Date.now() + 10 * 60 * 1000);
      user.passwordResetSentAt = new Date();
      await user.save();
      await sendEmailCode(email, 'Reset your BloodLink password', reset.code, 'password reset');
    }
    res.json({ message: 'If the account exists, a password reset code has been sent.' });
  } catch (error) {
    console.error('Password reset email failed:', error);
    res.status(503).json({ message: 'Email delivery is unavailable' });
  }
});

router.post('/reset-password', async (req, res) => {
  try {
    const email =
      typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';
    const password = req.body.password;
    if (!email || !/^\d{6}$/.test(code) || typeof password !== 'string' || password.length < 6) {
      return res.status(400).json({
        message: 'Enter your email, 6-digit code, and a password of at least 6 characters',
      });
    }
    const user = await User.findOne({ email, password: { $exists: true } });
    if (
      !user ||
      !user.passwordResetCodeHash ||
      !user.passwordResetExpiresAt ||
      user.passwordResetExpiresAt.getTime() < Date.now() ||
      !matchesEmailCode(code, user.passwordResetCodeHash)
    ) {
      return res.status(400).json({ message: 'Invalid or expired password reset code' });
    }
    user.password = await bcrypt.hash(password, 10);
    user.passwordResetCodeHash = undefined;
    user.passwordResetExpiresAt = undefined;
    user.passwordResetSentAt = undefined;
    await user.save();
    res.json({ message: 'Password reset. You can now sign in.' });
  } catch (error) {
    res.status(500).json({ message: 'Password reset failed', error });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({
      email: typeof email === 'string' ? email.trim().toLowerCase() : '',
    });
    if (!user || typeof password !== 'string' || !user.password) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }
    if (user.emailVerified === false) {
      return res.status(403).json({
        message: 'Please verify your email before signing in.',
        code: 'EMAIL_NOT_VERIFIED',
      });
    }

    const token = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, {
      expiresIn: '1d',
    });

    res.json({
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        bloodGroup: user.bloodGroup,
        division: user.division,
        district: user.district,
        upazila: user.upazila,
        status: user.status,
        role: user.role,
        picture: user.picture,
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
});

export default router;

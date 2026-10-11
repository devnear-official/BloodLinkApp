import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User.ts';
import { OAuth2Client } from 'google-auth-library';
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

    const { sub: googleId, email, name, picture } = payload;

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

    const existingUser = await User.findOne({ email });
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
    const user = new User({
      name,
      email,
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

    const token = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, {
      expiresIn: '1d',
    });

    res.status(201).json({
      message: 'User registered successfully',
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
      },
    });
  } catch (error: any) {
    console.error('Registration server error:', error);
    res
      .status(500)
      .json({ message: 'Server error', error: error.message || error });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
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
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
});

export default router;

# BloodLink

BloodLink is a Flutter blood donation and donor-matching app backed by a Node.js, Express, Socket.IO, and MongoDB API.

## Features

- Email/password and Google sign-in, email verification, password recovery, and persisted JWT sessions
- Donor search by blood group and location, with donation eligibility checks
- Blood requests, request responses, direct donor requests, and request history
- Nearby donor discovery with GPS radius and distance, location selection, and real-time request updates
- Editable donor profile, Cloudinary photo uploads, availability, admin user management, and donation history
- In-app, Socket.IO, and OneSignal mobile push notifications
- First-run onboarding, password confirmation, persistent dark mode, Bangla/English UI strings, and locally saved donors
- Paginated donor/request feeds and privacy-conscious offline donor-result cache
- Responsive Material 3 interface with a compact mobile navigation bar, desktop navigation rail, constrained reading widths, form validation, and loading/error states

## Run the backend

Install Node.js, copy `backend/.env.example` to `backend/.env`, and set the values needed by your deployment:

```dotenv
PORT=3000
MONGODB_URI=mongodb://127.0.0.1:27017/bloodlink
JWT_SECRET=replace-with-a-long-random-secret
ONESIGNAL_APP_ID=
ONESIGNAL_REST_API_KEY=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
SMTP_FROM=
```

From `backend/`, install dependencies once and start the development server:

```sh
npm install
npm run dev
```

The API is served at `http://localhost:3000`; its health endpoint is `http://localhost:3000/api/health`. MongoDB must be running and reachable before starting the server. SMTP enables verification and password-reset codes, Cloudinary stores uploaded profile photos, and OneSignal delivers mobile push notifications. Keep all provider secrets in backend environment variables, never in Flutter or source control.

For GPS-radius donor lookup, MongoDB must have a `2dsphere` index on `users.location`; Mongoose declares this index in the user model. If automatic index creation is disabled in production, create it once with `db.users.createIndex({ location: "2dsphere" })`.

## Run the Flutter app

From the repository root:

```sh
flutter pub get
flutter run --dart-define=ONESIGNAL_APP_ID=your-onesignal-app-id
```

The app defaults to `http://localhost:3000`. Override it at build/run time with `--dart-define=API_BASE_URL=...` when the backend is not reachable as localhost from the app:

```sh
# Android emulator (host machine's localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Add the OneSignal app ID to the same command:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=ONESIGNAL_APP_ID=your-onesignal-app-id

# Physical device (replace with the development machine's LAN address)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

For Flutter Web, use `http://localhost:3000` and run the backend on the same computer. The backend allows localhost origins for local web development. To receive mobile push, configure Android push credentials and iOS APNs in the OneSignal dashboard and enable notifications in the app's Settings. The app does not include Firebase Auth, Firestore, or Firebase Storage.

## Project layout

- `lib/`: Flutter UI, providers, models, API services, and shared infrastructure
- `lib/core/theme/app_theme.dart`: shared light/dark Material design tokens and component styles
- `backend/`: Express routes, MongoDB models, authentication, and Socket.IO events
- `assets/data/locations.json`: location data used by the registration and profile forms

## Current backend scope

This project is a blood donation app, so commerce-only concepts such as products, checkout, shopping carts, and order history do not map to its domain. Authentication and application data use the project's JWT + MongoDB API. Push uses OneSignal; email delivery uses SMTP; profile images use Cloudinary. Those external services require credentials in `backend/.env` and the OneSignal app ID at Flutter build time. Maps routing, QR, media playback, and analytics charts remain outside the current app scope.

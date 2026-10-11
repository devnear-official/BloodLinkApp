# BloodLink

BloodLink is a Flutter blood donation and donor-matching app backed by a Node.js, Express, Socket.IO, and MongoDB API.

## Features

- Email/password and Google sign-in, registration, and persisted JWT sessions
- Donor search by blood group and location, with donation eligibility checks
- Blood requests, request responses, direct donor requests, and request history
- Nearby donor discovery, location selection, and real-time request updates
- Editable donor profile, availability, admin user management, and donation history
- In-app notifications and web push subscription support
- Responsive Material 3 interface, form validation, loading and error states

## Run the backend

Install Node.js, then configure `backend/.env`:

```dotenv
PORT=3000
MONGODB_URI=mongodb://127.0.0.1:27017/bloodlink
JWT_SECRET=replace-with-a-long-random-secret
```

From `backend/`, install dependencies once and start the development server:

```sh
npm install
npm run dev
```

The API is served at `http://localhost:3000`; its health endpoint is `http://localhost:3000/api/health`. MongoDB must be running and reachable before starting the server. Google sign-in and web push need their respective provider credentials to be configured.

## Run the Flutter app

From the repository root:

```sh
flutter pub get
flutter run
```

The app defaults to `http://localhost:3000`. Override it at build/run time with `--dart-define=API_BASE_URL=...` when the backend is not reachable as localhost from the app:

```sh
# Android emulator (host machine's localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Physical device (replace with the development machine's LAN address)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

For Flutter Web, use `http://localhost:3000` and run the backend on the same computer. The backend allows localhost origins for local web development.

## Project layout

- `lib/`: Flutter UI, providers, models, API services, and shared infrastructure
- `backend/`: Express routes, MongoDB models, authentication, and Socket.IO events
- `assets/data/locations.json`: location data used by the registration and profile forms

## Current backend scope

This project is a blood donation app, so commerce-only concepts such as products, checkout, favorites, and order history do not map to its domain. Firebase Auth/Firestore/Storage, email verification/reset delivery, image upload, maps routing, QR, media playback, and calendar/chart modules are not configured in the current backend or app. Authentication and data currently use the project's JWT + MongoDB API; add credentials and domain requirements before enabling third-party services.

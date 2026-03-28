# Anti-Proxy Smart Attendance System

## Overview
A secure, multi-layer verification system for Indian colleges to prevent proxy attendance.

### 4 Pillars of Verification
1. **OTP**: Student requests via app, Admin issues verbally (Device binding).
2. **Dynamic QR**: Faculty generates a QR that refreshes every 10 seconds.
3. **Geo-fencing**: System verifies student is within the classroom radius (e.g., 25m).
4. **Facial Recognition**: Live selfie matches the student's registered photo using ML Kit.

## Tech Stack
- **Frontend**: Flutter (Riverpod for state management)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Sensors**: Geolocator (GPS), Mobile Scanner (QR), ML Kit (Face Detection)

## Setup Instructions

### 1. Flutter Setup
Since no SDK was found here, manually:
1. Install Flutter SDK: [flutter.dev](https://docs.flutter.dev/get-started/install)
2. Add `flutter` to your PATH.
3. Run `flutter pub get` in this directory.

### 2. Firebase Configuration
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/).
2. Enable **Anonymous Auth** and **Email/Password Auth**.
3. Create a **Firestore Database** and **Firebase Storage** bucket.
4. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
5. Run `flutterfire configure` to generate `firebase_options.dart`.
6. Deploy Firestore rules using `firebase deploy --only firestore:rules`.

### 3. Roles Initial Setup
To start, manually add an admin user in Firestore:
- Collection: `users`
- Document ID: `admin123`
- Fields: `{ "name": "Admin", "role": "admin", "user_id": "admin123", "created_at": ServerTimestamp }`

## Folder Structure
- `lib/models`: Data models for Users, Sessions, and Attendance.
- `lib/services`: Firebase and sensor logic.
- `lib/views/admin`: User registration and OTP management.
- `lib/views/faculty`: Session creation and dynamic QR.
- `lib/views/student`: Verification flow and scanning.

## Security
- **Anti-Replay**: QR codes include a timestamp and expire in 60s.
- **Role Gating**: Strict Firestore rules ensure students only write their own attendance.

# 🚍 MyBus – Smart Travel Solution

MyBus is a Flutter-based application designed to simplify access to local bus services. It allows users to search buses, check schedules, and book tickets, while also enabling service providers to manage their operations efficiently.

---

## 📌 Installation Guide

### 1. Install Requirements

Make sure you have the following installed:

* Flutter SDK → https://docs.flutter.dev/get-started/install
* Dart (comes with Flutter)
* Android Studio or VS Code
* Git

---

### 2. Clone the Repository

```bash
git clone https://github.com/UdayPrakashMinz/mybus.git
cd mybus
```

---

### 3. Install Dependencies

```bash
flutter pub get
```

---

## 🔥 Firebase Setup (Using Firebase CLI)

This project uses Firebase for backend services.

---

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify installation:

```bash
firebase --version
```

---

### 2. Login to Firebase

```bash
firebase login
```

This will open a browser for authentication.

---

### 3. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Add Dart global path (if not already added):

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Verify:

```bash
flutterfire --version
```

---

### 4. Create a Firebase Project

Create a project manually (recommended):
https://console.firebase.google.com/

---

### 5. Configure Firebase in Flutter

Inside your project folder, run:

```bash
flutterfire configure
```

This will:

* Detect your Flutter project
* Ask you to select a Firebase project
* Let you select platforms (Android, iOS, etc.)
* Generate `firebase_options.dart`

---

### 6. Platform Configuration

The CLI will automatically:

* Register Android app
* Register iOS app (if selected)
* Download required config files

Generated files:

* Android → `android/app/google-services.json`
* iOS → `ios/Runner/GoogleService-Info.plist`

---

### 7. Enable Firebase Services

Go to Firebase Console and enable:

#### Authentication

* Email/Password
* Google Sign-In

#### Cloud Firestore

1. Go to **Build → Firestore Database**
2. Click **Create Database**
3. Choose:

   * Start in test mode (for development)
4. Select nearest region
5. Click **Enable**

---

### 8. Set Firestore Rules

1. Open Firestore → **Rules tab**
2. Remove default rules
3. Paste your custom rules

---

## ▶️ Run the App

```bash
flutter pub get
flutter run
```

---

## 📂 Project Structure

```
mybus/
│
├── lib/                # Main Flutter source code
├── assets/             # Images, icons, etc.
├── android/            # Android-specific files
├── ios/                # iOS-specific files
├── web/                # Web support (if enabled)
├── pubspec.yaml        # Dependencies & config
└── README.md           # Project documentation
```

---

## ✨ Features

* Bus search and filtering
* Route and schedule viewing
* Ticket booking system
* Firebase Authentication (Email + Google)
* Cloud Firestore integration
* Scalable backend structure

---

## ⚠️ Notes

* Do NOT upload Firebase config files (`google-services.json`, `GoogleService-Info.plist`) publicly
* Secure Firestore rules before production
* Keep API keys and secrets private

---

## 🚀 Conclusion

MyBus demonstrates how modern tools like Flutter and Firebase can be used to build a complete real-world application efficiently. It highlights how easy it is to develop, manage, and scale a mobile application with the right tools.

**It is easy to make an app — you just need to start it.**

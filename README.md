# Flutter POS Background Upload & Download Module

A production-grade, resilient file transfer feature module built for a **Point of Sale (POS) SaaS** system using **Clean Architecture**, **Flutter BLoC**, **Dio**, and **System Tray Notifications**.

Designed to handle real-world mission-critical transfers—such as importing massive product catalog files (>50MB images, videos, CSV spreadsheets) and exporting extensive audit/financial reports—even when the user navigates across different screens or minimizes the application.

---

## Architecture & Key Design Decisions

The application strictly follows **Clean Architecture** with a clear separation of concerns, decoupling UI presentation from network streams and operating system services.

```
lib/
├── core/
│   ├── constants/             # API endpoints, timeouts, storage keys
│   ├── errors/                # Domain Failures & Data Exceptions
│   ├── network/               # DioClient with Auth interceptor & exception mapping
│   ├── notifications/         # NotificationService with progress throttling & deep linking
│   ├── storage/               # Secure token persistence & SharedPreferences fallback
│   └── usecase/               # Base UseCase contract
├── features/
│   ├── auth/                  # Authentication module (Domain, Data, Presentation)
│   │   ├── data/              # AuthRemoteDataSource, AuthRepositoryImpl, AuthTokenModel
│   │   ├── domain/            # AuthToken entity, AuthRepository, Login/Logout UseCases
│   │   └── presentation/      # AuthBloc, LoginScreen
│   └── file_transfer/         # Background Transfer module (Domain, Data, Presentation)
│       ├── data/              # FileRemoteDataSource, FileTransferRepositoryImpl, FileItemModel
│       ├── domain/            # TransferTask, FileItem entities, UseCases, TransferRepository
│       └── presentation/      # TransferBloc, FileListBloc, UI Screens & Widgets
│           ├── screens/       # HomeShellScreen, UploadScreen, DownloadScreen
│           └── widgets/       # PersistentTransferBanner, PersistentTransferSheet, TransferItemTile
└── main.dart                  # Dependency injection & root MultiBlocProvider
```

### Why This Architecture?
1. **Single Source of Truth**:
   The transfer engine (`FileTransferRepositoryImpl`) maintains persistent transfer tasks in a centralized repository decoupled from the UI lifecycle. If an operator initiates a 100MB upload on `UploadScreen` and switches tabs to `DownloadScreen`, the stream continues uninterrupted.
2. **Predictable State Flow via BLoC**:
   `TransferBloc` subscribes directly to the repository's `transferStream`. Any byte chunk sent/received or status change (running, paused, completed, failed) automatically updates the UI and recalculates aggregate metrics (such as `overallProgress` and active task counts) without rebuilding unrelated widgets.
3. **Decoupled System Notifications**:
   `NotificationService` handles Android/iOS notification channel initialization, badge updates, and notification taps. To prevent OS notification throttling, progress notifications are throttled to a minimum interval of 600ms per task while in-app progress updates remain smooth at 60fps.

---

## Background Execution Strategy & Android Platform Limits

Operating systems have increasingly placed aggressive restrictions on background processing to preserve battery life and memory. Here is how this module navigates those constraints:

### 1. In-App Background vs. App Minimization
* **Screen Navigation**: Transfers run on asynchronous Dart isolates and Dio stream subscriptions owned by the singleton repository. Navigating or popping screens in Flutter does not destroy the transfer.
* **App Minimized (Backgrounded)**:
  * When the app moves to the background, Android and iOS allow open socket connections to finish active transfers for a limited window (~30 seconds on iOS, variable on Android depending on memory pressure).
  * System tray notifications inform the user of ongoing progress and provide an immediate deep link back to the transfer dashboard upon tap.

### 2. Android OS Platform Limits & Mitigations

| Android OS Restriction | Impact on Background Transfers | How This Module Handles It |
| :--- | :--- | :--- |
| **Doze Mode (Android 6.0+)** | When the device is unplugged, stationary, and screen is off, the OS suspends network access and CPU wakelocks except during periodic maintenance windows. | The app holds a `WAKE_LOCK` permission and displays ongoing notifications. For true multi-hour transfers, apps must request exemption from battery optimizations (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). |
| **Android 14+ Foreground Service Types** | Android 14 (API 34+) mandates explicit declarations for any foreground service (`foregroundServiceType="dataSync"`). Uncategorized background services are immediately terminated by the OS. | Declared `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />` and configured notification channels accordingly. |
| **Cleartext Traffic Policy (Android 9+)** | Android blocks non-HTTPS HTTP traffic by default, preventing access to raw IP endpoints (`http://108.136.142.112:90`). | Configured `android:usesCleartextTraffic="true"` in `AndroidManifest.xml` to allow communication with the mock REST backend. |
| **OEM Battery Managers** | Aggressive OEM managers (Xiaomi MIUI, Samsung OneUI, Huawei EMUI) kill background apps within minutes regardless of stock Android specifications. | The UI clearly displays transfer state and notifies operators when a transfer is paused or failed, allowing immediate manual or automatic one-tap resumption. |

---

## Resilience & Transfer Mechanics

### Resumable Downloads (HTTP `Range` Header)
The mock backend supports byte-range requests (`curl -C - ...`). The download engine takes full advantage of this:
1. When downloading a file (e.g. `catalog.csv`), it writes incoming chunks to `catalog.csv.part`.
2. If connectivity drops or the user pauses, the file connection is closed cleanly.
3. On resume:
   * The app checks the length of `catalog.csv.part` on disk (e.g. 24,500,000 bytes).
   * It sends a `Range: bytes=24500000-` header to the server.
   * If the server replies with **HTTP 206 Partial Content**, the app opens an `IOSink` in `FileMode.append` and continues writing from byte 24,500,001 without restarting from 0%.
   * Upon reaching 100%, the `.part` file is atomic-renamed to its final path and a completion notification is triggered.

### Multipart Upload Pausing vs. Resuming
Standard HTTP multipart (`POST /upload`) does not natively support mid-stream byte-range resumption unless the backend implements a chunking protocol (such as [tus.io](https://tus.io) or AWS S3 multipart).
* **When Paused**: The app immediately aborts the active stream via a Dio `CancelToken`, marks the task as `Paused`, and cancels the active notification.
* **When Resumed**: The operator can resume or retry the upload without restarting the app.

---

## Global Transfer Dashboard & Floating UI

* **Persistent Floating Banner (`PersistentTransferBanner`)**:
  Visible across all screens whenever an upload or download is active. Shows aggregate progress, active transfer count, and opens the detailed dashboard on tap.
* **Expandable Transfers Sheet (`PersistentTransferSheet`)**:
  Displays full details for all running, paused, failed, and completed transfers, with per-item `Pause`, `Resume`, `Retry`, and `Cancel` controls, plus a "Clear Finished" option.
* **Deep Linking**:
  Tapping a completed upload or download notification in the Android system tray launches the app and highlights the relevant item.

---

## Running & Building the Project

### Prerequisites
- **Flutter SDK**: 3.27+ (Dart 3.13+)
- **Android SDK**: compileSdk 36, minSdk 21
- **Java**: JDK 17

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run All Unit & BLoC Tests
```bash
flutter test
```
*Current test suite: **70 passing tests** covering data sources, repositories, use cases, BLoCs, and widget rendering.*

### 3. Run on Connected Device / Emulator
```bash
flutter run
```

### 4. Build Android Debug APK
```bash
flutter build apk --debug
```
*The compiled APK will be located at:*
```
build/app/outputs/flutter-apk/app-debug.apk
```

---

## Known Limitations & Future Enhancements

1. **Protocol-Level Upload Resumption (tus.io / S3 Multipart)**:
   While downloads support native byte resumption via HTTP 206, multipart uploads on this mock server must re-stream from 0%. Supporting a chunked upload protocol would enable byte-level upload resumption.
2. **WorkManager / Native Background Tasks**:
   For transfers that must initiate or survive even after the user forcefully swipes the app away from the recent apps switcher, integrating Android `WorkManager` and iOS `BGProcessingTask` with a local SQLite queue (`drift` or `isar`) would provide headless background execution.
3. **Bandwidth Throttling**:
   Adding network-quality detection (`connectivity_plus`) to automatically pause transfers on mobile metered data and resume when connected to unmetered Wi-Fi.

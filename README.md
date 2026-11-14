# Flutter POS Background Upload & Download Module

**GitHub:** https://github.com/Nurujjaman329/laantech_project

A resilient file transfer feature module for a **Point of Sale (POS) SaaS** stack using **Clean Architecture**, **Flutter BLoC**, **Dio**, and **system tray notifications**.

Built for real-world scenarios such as importing large product catalogs (>50MB CSV / media) and exporting audit reports—transfers keep running when the operator switches screens, with progress notifications and manual resume after interruption.

**Mock API base URL:** `http://108.136.142.112:90`

---

## Quick start for reviewers

1. `flutter pub get`
2. `flutter run`
3. On the login screen **Register** a username/password (or **Sign In** if you already registered), then use the app
4. Upload via **Upload** tab (pick a file or generate the **>50MB Sample** CSV)
5. Download via **Download** tab (list → download → open)
6. Watch progress on-screen, in the floating banner / transfer sheet, and in system notifications  
   - Notification tap opens the **Upload** or **Download** tab and the transfer sheet

---

## Architecture & Key Design Decisions

The app follows **Clean Architecture** with a clear split between UI, domain, and data.

```
lib/
├── core/
│   ├── constants/             # API endpoints, timeouts, demo credentials, storage keys
│   ├── errors/                # Domain Failures & Data Exceptions
│   ├── network/               # DioClient (auth interceptor + debug API logs)
│   ├── notifications/         # NotificationService + FGS guard + tap router
│   ├── storage/               # Secure token persistence & SharedPreferences fallback
│   └── usecase/               # Base UseCase contract
├── features/
│   ├── auth/                  # Authentication (Domain, Data, Presentation)
│   └── file_transfer/         # Transfer engine + UI (Domain, Data, Presentation)
│       ├── data/              # FileRemoteDataSource, FileTransferRepositoryImpl
│       ├── domain/            # TransferTask, FileItem, UseCases, Repository contract
│       └── presentation/      # TransferBloc, FileListBloc, screens & widgets
└── main.dart                  # Manual DI & root MultiBlocProvider
```

### Screens
1. **Login / Register** — Sign In and Register against the mock API.
2. **Dashboard** — Sync stats, shortcuts, and live active transfers.
3. **Upload** — File picker + 1-click 50MB sample CSV + on-screen progress / pause / resume / retry.
4. **Download** — Remote file list, resumable download, open completed files.
5. **Transfer Manager** — Search + status filters (`All` / `Active` / `Completed` / `Failed`), Retry All, per-task controls.
6. **Settings** — Backend/timeout overview and logout.
7. **Global chrome** — Persistent floating banner + AppBar badge → transfer sheet (available on every tab).

### Why this shape?
1. **Single source of truth** — `FileTransferRepositoryImpl` owns in-flight Dio transfers and task state. Switching tabs does not cancel work.
2. **BLoC as UI adapter** — `TransferBloc` listens to `transferStream` and fans progress into screens, banner, and Transfer Manager.
3. **Notifications as OS surface** — While the FGS is running successfully, its ongoing notification shows live progress (e.g. `Uploading catalog.csv · 63%` or `2 transfers · 41% avg`, throttled ≤1/s) and per-task progress tray notifications are skipped to avoid duplicates. If FGS start fails, per-task progress notifications still show. Completion and error notifications always fire. Taps are routed by payload (`upload_<id>` / `download_<id>`) to the matching tab + sheet (including cold start).

---

## Background Execution Strategy & Android Platform Limits

### What “background” means in this submission

| Scenario | Behavior |
| :--- | :--- |
| Switch tabs / leave Upload or Download screen | Transfer **continues** (repository-owned Dio request, not tied to widget lifecycle). |
| App minimized while process stays alive | Typed `dataSync` FGS + ongoing notification with file name / % keep the process eligible to run. |
| Process killed / swipe away from Recents | In-flight sockets die. Tasks persisted in SharedPreferences are restored as **paused** (`Transfer paused (app was closed)`). Operator taps **Resume**. |
| Download resume after kill / pause | **Byte resume** via `.part` file + HTTP `Range` / 206 (HTTP **416** with a full `.part` finalizes as completed). |
| Upload resume after pause / kill | **Restarts from 0%** (mock multipart API has no chunk protocol). |

Transfers run as **async Dio work on the main Dart isolate**, owned by the repository singleton (not a separate isolate pool). While any transfer is **running/queued**, Android starts a typed **`dataSync` Foreground Service** via `flutter_foreground_task` with an ongoing progress notification so the process can keep working when the app is **minimized**. Force-stop / swipe-kill still ends sockets; tasks restore as **paused** for manual Resume.

### Android limits (honest mapping)

| Android restriction | Impact | What this module does today |
| :--- | :--- | :--- |
| **Doze / App Standby** | Network/CPU deferred when screen off & idle | Typed `dataSync` FGS + ongoing notification while transfers are active; after kill, paused task + manual Resume. Battery-optimization exemption is **not** requested. |
| **Android 14+ FGS types** | Background work without a typed FGS can be killed | Manifest + `flutter_foreground_task` service with `foregroundServiceType="dataSync"`. Service starts/stops with active transfer count. |
| **Cleartext (Android 9+)** | Blocks plain HTTP by default | `android:usesCleartextTraffic="true"` so the mock `http://108.136.142.112:90` API works. |
| **OEM battery killers** | May kill the process minutes after minimize | FGS reduces risk while transferring; persist tasks; restore as paused; one-tap Resume. Downloads continue from `.part`. |

`workmanager` is listed as an optional package in the assignment brief; it is **intentionally not used** here. Headless restart after process death still needs WorkManager / a durable queue (see Known Limitations).

---

## Resilience & Transfer Mechanics

### Resumable downloads (HTTP `Range`)
1. Chunks write to `{filename}.part` under app documents:  
   `{ApplicationDocumentsDirectory}/pos_downloads/` (reliable local resume target)
2. On pause / failure / app kill, the `.part` file remains.
3. On Resume: send `Range: bytes={existingLength}-`. On **HTTP 206**, append; on full **200**, restart cleanly.
4. On success: atomic rename `.part` → final file; **copy into public** `Downloads/POS_Transfers/` via Android **MediaStore**; completion notification; **Open** (`open_filex`) and **Share** (`share_plus`).

### Multipart upload pause / resume
- **Pause** — Dio `CancelToken` abort → status `paused`.
- **Resume / Retry** — restarts the full multipart `POST /upload` from 0% (server constraint, not a client bug).

### Errors & poor network
Friendly mapping for timeouts, offline (`SocketException`), 401, invalid/empty uploads, and server errors, with **Retry** on failed tasks. A **401 / auth expiry** during transfer signals logout back to the login screen. Debug builds also print every API call via `[API]` logs in `DioClient`.

**Connectivity auto-pause:** when the device goes offline, running transfers are paused with reason `Paused — network offline`. When connectivity returns, a snackbar offers **Resume** for those network-paused tasks (manual Pause is left alone). An offline banner also appears under the AppBar.

**Clear Finished:** removes completed/cancelled tasks from memory **and** SharedPreferences so they stay gone after restart.

---

## Global Transfer UI & Notification Deep Links

* **PersistentTransferBanner** — aggregate progress across tabs.
* **PersistentTransferSheet** — full list with Pause / Resume / Retry / Cancel / Clear Finished.
* **Notification deep link** — payload `upload_*` → Upload tab; `download_*` → Download tab; otherwise Transfers tab; then opens the transfer sheet. Cold-start launch payload is handled via `getNotificationAppLaunchDetails`.

---

## How to test background behavior

Manual checks on a **real Android device** (emulator is weaker for FGS / OEM battery rules):

1. **Minimize + screen off (5+ minutes)** — start a large upload or download, press Home, turn the screen off for 5+ minutes. Expect the FGS notification to stay up and the transfer to keep progressing (or finish).
2. **Swipe away then reopen** — start a transfer, swipe the app from Recents, reopen. Tasks should restore as **paused** with message about app closed; tap **Resume**. Downloads should continue from the `.part` size, not 0%.
3. **Airplane mode** — during a transfer, enable airplane mode (auto-pause + offline banner), then disable it and accept the **Resume** snackbar for network-paused tasks.
4. **Download resume size** — pause mid-download, note `.part` growth / progress %, resume and confirm progress continues (not reset).
5. **Public Downloads** — after a successful download, open the system **Files** app → **Downloads** → **POS_Transfers** and confirm the file is visible.
6. **Notification tap** — while a transfer is running, tap the FGS / completion notification; expect the correct Upload/Download tab + transfer sheet. Force-stop the app, then tap a completion notification (cold start) and confirm routing still works.
7. **Android 13+ notification permission** — on first launch (API 33+), allow notifications when prompted; without it, tray progress/completion may not appear.

### Verify on device
These behaviors depend on OEM battery policy and cannot be fully proven in unit tests alone: long minimize with screen off, FGS survival under aggressive OEMs, and MediaStore visibility in the Files app.

---

## Running & Building

### Prerequisites
- Flutter SDK 3.27+ (Dart 3.13+)
- Android SDK: compileSdk 36, **minSdk 24** (`flutter.minSdkVersion`; required by `flutter_secure_storage` / `shared_preferences_android`)
- JDK 17

### Commands
```bash
flutter pub get
flutter test
flutter run
flutter build apk --debug
```

Debug APK output:
```
build/app/outputs/flutter-apk/app-debug.apk
```

Current test suite: **116 passing tests** (data sources, repositories, use cases, BLoCs, connectivity, notification router, widgets).

---

## Known Limitations & What I’d Improve With More Time

1. **Upload byte-level resume** — needs tus.io / S3 multipart (or similar) on the backend; client currently restarts multipart from 0%.
2. **Post-kill headless restart** — FGS covers **minimize** while the process lives. After process death, add Android `WorkManager` (+ durable queue such as Drift/Isar) and iOS `BGProcessingTask` so jobs can restart without only manual Resume.
3. **Smarter network policies** — today we auto-pause on any offline and prompt Resume when back; could also pause on metered cellular and prefer Wi‑Fi only.

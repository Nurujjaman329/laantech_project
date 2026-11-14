# Flutter POS Background Upload & Download Module

**GitHub:** https://github.com/Nurujjaman329/laantech_project

A resilient file transfer feature module for a **Point of Sale (POS) SaaS** stack using **Clean Architecture**, **Flutter BLoC**, **Dio**, and **system tray notifications**.

Built for real-world scenarios such as importing large product catalogs (>50MB CSV / media) and exporting audit reports—transfers keep running when the operator switches screens, with progress notifications and manual resume after interruption.

**Mock API base URL:** `http://108.136.142.112:90`

---

## Quick start for reviewers

1. `flutter pub get`
2. `flutter run`
3. On the login screen either:
   - **Register** a new username/password, then use the app, or
   - Tap **1-Click Demo Operator Access** — this performs a **real** `/token` login (auto-registers `pos_demo_operator` on first use) and persists a real Bearer token
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
│   ├── notifications/         # NotificationService + TransferNotificationRouter
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
1. **Login / Register** — Sign In, Register, and 1-Click Demo (real API auth).
2. **Dashboard** — Sync stats, shortcuts, and live active transfers.
3. **Upload** — File picker + 1-click 50MB sample CSV + on-screen progress / pause / resume / retry.
4. **Download** — Remote file list, resumable download, open completed files.
5. **Transfer Manager** — Search + status filters (`All` / `Active` / `Completed` / `Failed`), Retry All, per-task controls.
6. **Settings** — Backend/timeout overview and logout.
7. **Global chrome** — Persistent floating banner + AppBar badge → transfer sheet (available on every tab).

### Why this shape?
1. **Single source of truth** — `FileTransferRepositoryImpl` owns in-flight Dio transfers and task state. Switching tabs does not cancel work.
2. **BLoC as UI adapter** — `TransferBloc` listens to `transferStream` and fans progress into screens, banner, and Transfer Manager.
3. **Notifications as OS surface** — Progress (throttled ~600ms), completion, and error notifications. Taps are routed by payload (`upload_<id>` / `download_<id>`) to the matching tab + sheet (including cold start).

---

## Background Execution Strategy & Android Platform Limits

### What “background” means in this submission

| Scenario | Behavior |
| :--- | :--- |
| Switch tabs / leave Upload or Download screen | Transfer **continues** (repository-owned Dio request, not tied to widget lifecycle). |
| App minimized while process stays alive | Socket may keep running for a limited OS window; ongoing notification shows progress. |
| Process killed / swipe away from Recents | In-flight sockets die. Tasks persisted in SharedPreferences are restored as **paused** (`Transfer paused (app was closed)`). Operator taps **Resume**. |
| Download resume after kill / pause | **Byte resume** via `.part` file + HTTP `Range` / 206. |
| Upload resume after pause / kill | **Restarts from 0%** (mock multipart API has no chunk protocol). |

Transfers run as **async Dio work on the main Dart isolate**, owned by the repository singleton. This is **not** a separate Dart isolate pool, and **WorkManager / a bound Foreground Service are not implemented** in this version (see Known Limitations).

### Android limits (honest mapping)

| Android restriction | Impact | What this module does today |
| :--- | :--- | :--- |
| **Doze / App Standby** | Network/CPU deferred when screen off & idle | Ongoing progress notifications while the process is alive; after kill, paused task + manual Resume. Battery-optimization exemption is **not** requested in code. |
| **Android 14+ FGS types** | Background work without a typed FGS can be killed | Manifest declares `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` and `WAKE_LOCK` for forward compatibility. **No `<service>` / FGS starter is wired yet** — notifications alone do not create a foreground service. |
| **Cleartext (Android 9+)** | Blocks plain HTTP by default | `android:usesCleartextTraffic="true"` so the mock `http://108.136.142.112:90` API works. |
| **OEM battery killers** | May kill the process minutes after minimize | Persist tasks; restore as paused; one-tap Resume. Downloads continue from `.part`. |

`workmanager` is listed as an optional package in the assignment brief; it is **intentionally not used** here. Limits are documented instead of over-claiming headless survival.

---

## Resilience & Transfer Mechanics

### Resumable downloads (HTTP `Range`)
1. Chunks write to `{filename}.part` under app documents:  
   `{ApplicationDocumentsDirectory}/pos_downloads/`
2. On pause / failure / app kill, the `.part` file remains.
3. On Resume: send `Range: bytes={existingLength}-`. On **HTTP 206**, append; on full **200**, restart cleanly.
4. On success: atomic rename `.part` → final file; completion notification; **Open** via `open_filex`.

### Multipart upload pause / resume
- **Pause** — Dio `CancelToken` abort → status `paused`.
- **Resume / Retry** — restarts the full multipart `POST /upload` from 0% (server constraint, not a client bug).

### Errors & poor network
Friendly mapping for timeouts, offline (`SocketException`), 401, and server errors, with **Retry** on failed tasks. Debug builds also print every API call via `[API]` logs in `DioClient`.

**Connectivity auto-pause:** when the device goes offline, running transfers are paused with reason `Paused — network offline`. When connectivity returns, a snackbar offers **Resume** for those network-paused tasks (manual Pause is left alone). An offline banner also appears under the AppBar.

---

## Global Transfer UI & Notification Deep Links

* **PersistentTransferBanner** — aggregate progress across tabs.
* **PersistentTransferSheet** — full list with Pause / Resume / Retry / Cancel / Clear Finished.
* **Notification deep link** — payload `upload_*` → Upload tab; `download_*` → Download tab; otherwise Transfers tab; then opens the transfer sheet. Cold-start launch payload is handled via `getNotificationAppLaunchDetails`.

---

## Running & Building

### Prerequisites
- Flutter SDK 3.27+ (Dart 3.13+)
- Android SDK: compileSdk 36, minSdk 21
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

Current test suite: **84 passing tests** (data sources, repositories, use cases, BLoCs, connectivity, notification router, widgets).

### Demo credentials (1-Click Demo)
- Username: `pos_demo_operator`
- Password: `DemoPass123!`  
Auto-registered on first Demo tap against the live mock API.

---

## Known Limitations & What I’d Improve With More Time

1. **Upload byte-level resume** — needs tus.io / S3 multipart (or similar) on the backend; client currently restarts multipart from 0%.
2. **True OS background survival** — add Android `WorkManager` + typed `dataSync` Foreground Service, and iOS `BGProcessingTask`, with a durable queue (e.g. Drift/Isar) so transfers can continue or restart after process death without relying only on manual Resume.
3. **Smarter network policies** — today we auto-pause on any offline and prompt Resume when back; could also pause on metered cellular and prefer Wi‑Fi only.
4. **Public Downloads folder (optional)** — files currently land in app-private `pos_downloads/` (sensible & permission-light); MediaStore / system Downloads could be added for easier file-manager discovery.
5. **Clear Finished persistence** — clearing finished tasks in the sheet currently updates UI state; tightening SharedPreferences sync would keep cleared items gone after restart.

# JavisAudit — Mobile Digital Ledger System

A fully offline-first Flutter mobile app that digitises the paper ledger
for Ghanaian micro and small-scale enterprises (MSEs), with automatic
GRA VAT threshold (GHS 750,000) tracking.

Built from the project's **System Flow Document** (sign-up → database),
this codebase implements every screen, table, and workflow specified
there — fully commented so you can read the code as a learning resource.

---

## 1. Project Structure

```
javisaudit/
├── lib/
│   ├── main.dart                  # App entry point, Hive + notification + DB init
│   ├── database/
│   │   └── database_helper.dart   # ALL SQLite logic lives here (singleton)
│   ├── models/
│   │   └── models.dart            # Income, Expense, Sale, BusinessProfile classes
│   ├── providers/
│   │   ├── providers.dart         # IncomeProvider, ExpenseProvider, SalesProvider, ProfileProvider
│   │   └── vat_provider.dart      # VAT threshold tracking + local notifications
│   ├── screens/
│   │   ├── splash_screen.dart         # Step 1
│   │   ├── onboarding_screen.dart     # Step 2 — business profile setup
│   │   ├── main_nav_screen.dart       # Bottom nav shell (5 tabs)
│   │   ├── dashboard_screen.dart      # Step 4 — home / KPIs / charts
│   │   ├── income_screen.dart         # Step 5
│   │   ├── expense_screen.dart        # Step 6
│   │   ├── sales_screen.dart          # Step 7
│   │   ├── more_screen.dart           # Hub menu for the screens below
│   │   ├── vat_tracker_screen.dart    # Step 9 — the flagship feature
│   │   ├── reports_screen.dart        # Step 8 — Weekly/Monthly/P&L/Category
│   │   ├── audit_report_screen.dart   # Step 10 — Year-end PDF generation
│   │   ├── backup_screen.dart         # Step 11 — JSON export/import
│   │   └── settings_screen.dart       # Step 11 — edit profile, delete data
│   └── utils/
│       └── utils.dart             # AppColors + AppFormat (currency/date helpers)
├── android/                       # Native Android project (manifest, gradle)
├── pubspec.yaml                   # All dependencies, explained inline
├── analysis_options.yaml          # Linter rules
└── README.md                      # This file
```

Every file begins with a comment block explaining its purpose, and
every non-trivial line has an inline `//` comment explaining *why*,
not just *what*.

---

## 2. Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | 3.22+ | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.2+ (bundled with Flutter) | — |
| Android Studio or VS Code | Latest | with the Flutter & Dart plugins |
| Android SDK | API 26–34 | via Android Studio SDK Manager |
| A physical Android device (USB debugging on) or an emulator | Android 8.0+ | — |

Verify your setup:

```bash
flutter doctor
```

Fix anything marked with a red ✗ before continuing.

---

## 3. First-Time Setup

```bash
# 1. Navigate into the project folder
cd javisaudit

# 2. Download all dependencies declared in pubspec.yaml
flutter pub get

# 3. (Optional) Run static analysis to catch issues early
flutter analyze
```

If `flutter analyze` reports anything, read the message — it will
point at the exact file and line.

---

## 4. Running the App (Development)

```bash
# Plug in an Android device via USB (with USB debugging enabled)
# or start an emulator from Android Studio, then:
flutter devices        # confirm your device is detected
flutter run             # builds and launches the app with hot reload
```

While `flutter run` is active:
- Press `r` for hot reload (instant UI updates without losing state)
- Press `R` for hot restart (full app restart, state is reset)
- Press `q` to quit

### First Launch Behaviour
On a brand-new install, the database is empty, so the app will show
the **Onboarding Screen** first. Fill in your business details — this
cannot be skipped, as per the system spec. After saving, you'll land
on the Dashboard with all five bottom-nav tabs available.

---

## 5. Building a Release APK

```bash
# Build a release-mode APK (smaller, optimised, no debug banner)
flutter build apk --release

# The output file will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

To install it directly on a connected device:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Building an App Bundle (for Play Store submission)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

> **Note on signing:** `android/app/build.gradle` currently uses the
> default debug signing config so the build works out of the box.
> Before publishing to the Play Store, generate your own upload
> keystore and update the `signingConfigs` block — see
> https://docs.flutter.dev/deployment/android#signing-the-app

---

## 6. How the App Works (Code Walkthrough)

### 6.1 Startup Sequence (`main.dart`)
1. `WidgetsFlutterBinding.ensureInitialized()` — required before any
   async native calls.
2. `Hive.initFlutter()` + `Hive.openBox('settings')` — sets up the
   lightweight key-value store used for notification flags.
3. `DatabaseHelper.instance.database` — opens (or creates on first
   run) `javisaudit.db` and all 5 SQLite tables.
4. `flutterLocalNotificationsPlugin.initialize()` — registers the app
   with Android's notification system.
5. `_resetNotificationFlagsIfNewYear()` — ensures VAT alerts can fire
   again each new calendar year.
6. `runApp(MultiProvider(...))` — wraps the whole app so any screen
   can read live data via `context.watch<XProvider>()`.

### 6.2 The Database Layer (`database/database_helper.dart`)
This is the **only** file that contains raw SQL. It is a singleton
(`DatabaseHelper.instance`) so the whole app shares one open
connection. Every other file calls typed methods like
`insertIncome()`, `getAnnualTurnover()`, `getMonthlyIncomeBreakdown()`
— no SQL leaks into the UI layer.

The 5 tables (see Section 4 of the system flow document):
- `business_profile` — singleton row, the business identity
- `income` — every money-in entry
- `expenses` — every money-out entry
- `sales` — itemised sales; auto-creates an `income` row when
  `payment_status = 'Paid'` (see `SalesProvider.addSale()`)
- `settings` — app-level config (currency symbol, VAT threshold)

### 6.3 State Management Pattern (`providers/`)
Every screen follows the same 3-step pattern:
1. **Load**: `WidgetsBinding.instance.addPostFrameCallback` calls
   `provider.loadAll()` once the screen mounts.
2. **Watch**: `context.watch<XProvider>()` inside `build()` rebuilds
   the widget automatically whenever the provider's data changes.
3. **Mutate**: form submissions call `provider.addX(...)`, which
   inserts into SQLite then reloads the in-memory list and calls
   `notifyListeners()`.

### 6.4 The VAT Tracking Engine (`providers/vat_provider.dart`)
This is the heart of JavisAudit's value proposition:
- `loadTurnover()` queries `SUM(amount) FROM income WHERE year = ?`
- `percentageReached` compares that sum to the GHS 750,000 constant
- `_checkAndNotify()` checks 3 milestones (70%, 90%, 100%) and fires
  a **local** Android notification (no internet required) the first
  time each milestone is crossed in a calendar year — tracked via
  Hive flags so it never repeats.

### 6.5 PDF Generation (`screens/audit_report_screen.dart`)
Uses the `pdf` package to build a 5-page document entirely in Dart
(cover/summary → monthly table → income detail → expense detail →
disclaimer), then hands the generated bytes to `Printing.sharePdf()`,
which opens Android's native share sheet so the user can save or
forward the PDF.

### 6.6 Backup / Restore (`screens/backup_screen.dart`)
- **Export**: reads every table via `exportAllData()`, pretty-prints
  it as JSON, writes it to a temp file, and shares it via
  `share_plus`.
- **Restore**: `file_picker` opens a native file chooser restricted
  to `.json`, the file is parsed and validated, then
  `restoreFromBackup()` wipes and re-populates every table inside a
  single SQLite **transaction** — so a failure mid-restore can't
  leave the database half-empty.

---

## 7. Offline-First Guarantee

`android/app/src/main/AndroidManifest.xml` deliberately does **not**
declare the `INTERNET` permission. This is not an oversight — it is
a hard architectural guarantee that no business data entered into
JavisAudit can ever leave the device over a network, matching
Section 8.1 of the system specification.

---

## 8. Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| `flutter pub get` fails | Flutter SDK out of date | `flutter upgrade`, then retry |
| Build fails on `sqflite` | Missing Android NDK | Install via Android Studio → SDK Manager → SDK Tools |
| Notifications don't appear | Android 13+ runtime permission not granted | The app requests `POST_NOTIFICATIONS` — accept the system prompt on first launch |
| App shows Onboarding every time | Emulator wiped on restart | Use a persistent emulator or physical device |
| PDF share sheet doesn't open | No share-capable app installed | Install Gmail, WhatsApp, or any file manager that supports the share intent |

---

## 9. Roadmap

See Section 9 of the System Flow Document for the full v1.1–v3.0
roadmap (PIN lock, iOS support, multi-currency, GRA e-filing
integration, cloud backup, AI insights).

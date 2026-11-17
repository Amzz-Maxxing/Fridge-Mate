# Fridge Mate — Developer Guide

**Fridge Mate** (by **ShelfLife**) is a Flutter app that tracks what's in your
fridge, reminds you before food expires, suggests meals that use expiring food
first, and builds a smart grocery list.

This guide gets a new developer from a fresh PC to running and changing the
app. If you only want to *install and use* the app, see [`../user`](../user).

---

## 1. What the app is built with

| Part | Technology | Used for |
|---|---|---|
| App | [Flutter](https://flutter.dev) 3.50 / Dart 3.14 | One codebase for Android and iOS |
| Accounts | Firebase Authentication (email + password) | Sign up / sign in |
| Database | Cloud Firestore | Fridge items, grocery list, saved lists, shopping history, favourites, meal plans, profile |
| AI | Firebase AI Logic → Google Gemini (`gemini-3.5-flash-lite`) | Fridge photo scanning, receipt scanning, AI meal ideas |
| Reminders | `flutter_local_notifications` (on-device scheduling) | Expiry reminders with recipe tips |
| Look | Custom theme in `lib/theme.dart` (Nunito font via `google_fonts`) | "Shelves" design, light & dark mode |

Firebase project: **`shelflife-fridgemate`**.

---

## 2. Tools to install

Install these once on your PC.

| Tool | Why | Get it |
|---|---|---|
| **Git** | Download and save code changes | https://git-scm.com/downloads |
| **Flutter SDK** (stable, 3.50 or newer) | Builds and runs the app | https://docs.flutter.dev/get-started/install |
| **Android Studio** | Android SDK, emulator, and an editor | https://developer.android.com/studio |
| **VS Code** (optional) | Lighter editor; install the *Flutter* extension | https://code.visualstudio.com |
| **Node.js** (LTS) | Needed for the Firebase CLI | https://nodejs.org |
| **Firebase CLI** | Deploy Firestore rules, manage Firebase | `npm install -g firebase-tools` — https://firebase.google.com/docs/cli |
| **FlutterFire CLI** | Reconnect the app to Firebase (e.g. after changing the app ID) | `dart pub global activate flutterfire_cli` — https://firebase.flutter.dev/docs/cli |
| **Xcode** (Mac only) | Needed only to build for iPhone | Mac App Store |
| **CocoaPods** (Mac only) | iOS dependencies | `sudo gem install cocoapods` |

### Windows-only tip
Turn on **Developer Mode** (Settings → System → For developers). Flutter needs
it to build plugins on Windows.

---

## 3. Accounts and websites you'll use

Ask the project owner to give you access to each of these.

| What | Link | What you do there |
|---|---|---|
| **GitHub repository** | https://github.com/Amzz-Maxxing/Frigde-Mate-v2 | Get the code, push changes. Owner adds you under *Settings → Collaborators*. |
| **Firebase console** | https://console.firebase.google.com/project/shelflife-fridgemate | Everything Firebase. Owner adds you under *Project settings → Users and permissions*. |
| Firestore data | https://console.firebase.google.com/project/shelflife-fridgemate/firestore | See/edit stored data, paste security rules |
| Authentication | https://console.firebase.google.com/project/shelflife-fridgemate/authentication | See user accounts, sign-in methods |
| AI Logic (Gemini) | https://console.firebase.google.com/project/shelflife-fridgemate/overview → *AI Logic* in the left menu | Gemini setup and usage |
| App Check | https://console.firebase.google.com/project/shelflife-fridgemate/appcheck | Protects AI Logic (see *Known issues*) |
| Google Cloud console | https://console.cloud.google.com/apis/dashboard?project=shelflife-fridgemate | API keys, quotas, billing |
| Flutter docs | https://docs.flutter.dev | Framework reference |
| Package site | https://pub.dev | Find/update Dart packages |
| Firebase for Flutter | https://firebase.flutter.dev | FlutterFire plugin docs |
| Design canvas (GUI & logo drafts) | Link shared by the project owner | Reference designs |

---

## 4. First-time setup

```bash
# 1. Get the code
git clone https://github.com/Amzz-Maxxing/Frigde-Mate-v2.git
cd Frigde-Mate-v2/developer

# 2. Check your tools (fix anything marked ✗)
flutter doctor

# 3. Download the app's packages
flutter pub get
```

Then in **Android Studio**: *More Actions → Virtual Device Manager → Create
device* (e.g. Pixel 8, a recent Android image). Start it.

> **Emulator clock tip:** if reminders fire at odd times, cold-boot the
> emulator (Device Manager → ⋮ → *Cold Boot Now*) and set *Settings → System
> → Date & time* to your time zone.

---

## 5. Running the app

```bash
flutter devices          # list emulators/phones
flutter run              # debug build: hot reload with  r , restart with  R
flutter run --release    # smooth build, like users get
```

**Real Android phone:** enable *Developer options → USB debugging*, plug in,
accept the prompt, then `flutter run`.

**iPhone (Mac only):** open `ios/Runner.xcworkspace` in Xcode, set
*Signing & Capabilities → Team* to your Apple ID, then `flutter run`. You may
need to change the bundle ID (`com.example.fridgeMate`) to something unique and
re-run `flutterfire configure` (see §8).

---

## 6. Project layout

```
developer/
├─ lib/
│  ├─ main.dart               App start-up, sign-in screen, light/dark switch
│  ├─ splash.dart             Animated logo loading screen
│  ├─ theme.dart              Colours (light & dark palette), fonts, brand marks
│  ├─ home_shell.dart         Floating pill navigation (Fridge / Meals / Groceries)
│  ├─ inventory_screen.dart   Fridge tab, shelves, add/edit item, "use some" sheet
│  ├─ scan_screen.dart        Fridge & receipt scanner (review screen)
│  ├─ scan_service.dart       Gemini prompts for scanning
│  ├─ ai_service.dart         Shared Gemini call + friendly errors
│  ├─ ai_recipes.dart         AI meal ideas
│  ├─ meal_screen.dart        Meals tab (For you / All recipes / Favourites), recipe page
│  ├─ meal_plan*.dart         Weekly meal planner + auto-plan + weekly shopping
│  ├─ recipes.dart            Recipe model + matching/scoring logic
│  ├─ recipe_data*.dart       The 116-recipe database (core / Asian / world)
│  ├─ grocery_screen.dart     Groceries tab
│  ├─ quick_add_sheet.dart    One-tap common ingredients
│  ├─ common_groceries.dart   Common-ingredient catalogue (English + Malay)
│  ├─ saved_lists.dart        Saved grocery lists
│  ├─ shopping_history.dart   Shopping trips
│  ├─ favourites.dart         Favourite recipes
│  ├─ profile.dart            Profile, photo, reminder time, appearance
│  ├─ notification_service.dart  Expiry reminders
│  └─ amounts.dart            Units (pcs, g, kg, ml, L…), conversions
├─ test/                      Unit tests  →  flutter test
├─ assets/                    Logo, app icon, launch-screen images
├─ firestore.rules            Firestore security rules (paste into console)
├─ android/ ios/ …            Platform projects
└─ pubspec.yaml               Packages, icon & launch-screen settings
```

---

## 7. Everyday tasks

| Task | How |
|---|---|
| Run tests | `flutter test` (all tests should pass before you push) |
| Check code | `flutter analyze` — on OneDrive folders, use `dart analyze lib/*.dart` (see *Known issues*) |
| Add a recipe | Copy an entry in `lib/recipe_data*.dart`; give it a unique `id`, `origin`, `diet`, and amounts in `pcs`/`pack`/`g`/`kg`/`ml`/`L` |
| Change colours | `lib/theme.dart` → `AppPalette.light` / `AppPalette.dark` |
| Change the app icon | Replace `assets/icon/*.png`, then `dart run flutter_launcher_icons` |
| Change the launch screen | Edit `flutter_native_splash` in `pubspec.yaml`, then `dart run flutter_native_splash:create` |
| Update Firestore rules | Edit `firestore.rules`, then paste into *Firestore → Rules → Publish* (or `firebase deploy --only firestore:rules`) |
| Build an APK for testers | `flutter build apk --release --split-per-abi` → `build/app/outputs/flutter-apk/` |
| Save your work | `git add -A`, `git commit -m "What you changed"`, `git push` |

Prefer a branch per feature: `git switch -c my-feature`, push it, then open a
Pull Request on GitHub.

---

## 8. Firebase notes

- The app's Firebase settings live in `lib/firebase_options.dart` and
  `android/app/google-services.json`. They identify the project; access is
  controlled by **Firestore rules** and **sign-in**, not by hiding these files.
- If you change the Android app ID or iOS bundle ID, register the new ID in
  Firebase and regenerate the settings: `flutterfire configure`.
- **Firestore rules** (`firestore.rules`) must be published whenever you add a
  new collection or field, or saving will fail with `PERMISSION_DENIED`.
- **AI Logic** must be enabled with the *Gemini Developer API*. If scans fail
  with an App Check error, see below.

---

## 9. Known issues

| Problem | Fix |
|---|---|
| Scan says "blocked by Firebase App Check" | App Check is enforced but the app doesn't send App Check tokens yet. Firebase → App Check → APIs → Firebase AI Logic → **Unenforce** (prototype), or add `firebase_app_check` to the app (proper fix). |
| `flutter analyze` says "No issues" suspiciously fast | OneDrive-synced folders can confuse it. Run `dart analyze lib/*.dart`, or keep the project outside OneDrive. |
| Windows build error about symlinks | Turn on Windows Developer Mode. |
| Photos dragged into the emulator don't show in the picker | `adb shell content call --uri content://media --method scan_volume --arg external_primary` |
| Reminders late on some phones | Phone battery savers delay alarms; set Fridge Mate's battery use to *Unrestricted*. |
| App ID is still `com.example…` | Must be changed (and re-registered in Firebase) before publishing to Google Play / App Store. |

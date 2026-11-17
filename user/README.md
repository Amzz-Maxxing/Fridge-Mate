# Fridge Mate — Install & Use

**Fridge Mate** (by **ShelfLife**) helps you use food before it expires:

- 📷 **Scan your fridge or receipt** and the app fills in your fridge list
- ⏰ **Reminders** the day before and the morning food expires, with recipe ideas
- 🍳 **116 recipes** (Malay, Chinese, Indian, Western and more), best matches for your fridge first, plus AI ideas
- 🛒 **Smart grocery list**, saved monthly lists, shopping history and a weekly meal planner

No coding needed. Pick **one** of the two ways below.

---

## Which file do I need?

| File | Use it for |
|---|---|
| **`FridgeMate-phone-arm64.apk`** | ✅ **Most Android phones** (2017 and newer). Start with this one. |
| `FridgeMate-phone-older-armv7.apk` | Older or budget phones, if the arm64 file says *"App not installed"* |
| `FridgeMate-emulator-x86_64.apk` | The Android Studio emulator on a PC (Way B) |

Requires **Android 7.0 or newer**. An iPhone version isn't available yet.

---

## Way A — Install on your Android phone

1. **Download the APK on your phone.** Open this repository on your phone's
   browser, tap **`FridgeMate-phone-arm64.apk`**, then tap **Download** (the ⤓
   button on the right).
2. **Open the downloaded file** (from the download notification or your
   *Files / Downloads* app).
3. If the phone says installing from this source isn't allowed, tap
   **Settings**, turn on **Allow from this source**, then go back.
4. Tap **Install**, then **Open**.
   - If *Play Protect* warns about an unknown app, tap **More details →
     Install anyway**. (The app isn't on the Play Store yet, so Google doesn't
     recognise it.)
5. **Create an account** with your email and a password.
6. When asked, **allow notifications** (for expiry reminders) and **camera**
   (for scanning).

**Updating later:** download the newer APK and install it over the old one;
your data stays in your account.

---

## Way B — Run it in Android Studio's emulator (on a PC)

Use this if you don't have an Android phone.

1. Install **Android Studio**: https://developer.android.com/studio
2. Open Android Studio → **More Actions → Virtual Device Manager → Create
   Virtual Device**. Pick **Pixel 8** (or any phone), choose the latest
   system image (click the download icon if needed), then **Finish**.
3. Press **▶** next to the new device to start the emulator and wait for the
   home screen.
4. Download **`FridgeMate-emulator-x86_64.apk`** from this folder to your PC.
5. **Drag the APK file onto the emulator window.** It installs automatically.
6. Open **Fridge Mate** from the emulator's app list, create an account and
   allow notifications.

**Tip — testing the scanner on the emulator:** drag food photos onto the
emulator window; they appear under *Downloads* when you choose
*Scan fridge → Choose from gallery*.

---

## Using the app

| Tab | What you can do |
|---|---|
| **Fridge** | See your food by shelf, tap **Scan** to photograph your fridge, **+** to add items. Swipe an item **right** to use some, **left** to remove it. |
| **Meals** | *For you* = recipes that fit your fridge; *All recipes* with filters (origin, diet, time); *Favourites* (♡). 📅 opens the weekly **meal planner**. |
| **Groceries** | Your shopping list. **+** for quick-add common items, 🧾 **Scan receipt** after shopping to fill your fridge. 🕘 shows shopping history; 🔖 saved lists. |
| **Profile** (your picture, top right of Fridge) | Photo, name, **reminder time**, **light/dark theme**, sign out. |

---

## Troubleshooting

| Problem | What to do |
|---|---|
| *"App not installed"* | Try `FridgeMate-phone-older-armv7.apk`. If you had an older test version, uninstall it first. |
| No reminders | Profile → check *Notifications are on*. On Xiaomi, Oppo, Vivo, Huawei or Samsung phones: *Settings → Apps → Fridge Mate → Battery → Unrestricted*. |
| Scanning fails | Check your internet connection and try a clearer, brighter photo. If it mentions *App Check* or *AI Logic*, tell the development team. |
| Can't sign in | Check the email and password; use *New here? Create an account* if you haven't signed up. |
| Reminders at the wrong time (emulator) | Emulator *Settings → System → Date & time* → set your time zone; cold-boot the emulator if the date is wrong. |

Questions or bugs? Open an **Issue** on this GitHub repository.

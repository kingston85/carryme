# Connecting CarryMe to Firebase

The app now runs in two modes:

| | Demo mode | Live mode |
|---|---|---|
| When | No Firebase settings in the build | `GOOGLE_SERVICES_JSON` secret is set |
| Login | Code `123456` | Real SMS code (Firebase phone sign-in) |
| Drivers | Simulated on the phone | Real drivers on other phones |
| Data | Only on the phone | Stored in your Firestore database |

Follow the steps once. It takes about 20 minutes.

---

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and sign in with your Google account.
2. Click **Create a project** and name it `CarryMe` (or anything you like).
3. You can turn Google Analytics off. Click **Create project**.

## 2. Register the Android app

1. On the project home page, click the **Android** icon ("Add app").
2. **Android package name:** `lr.carryme.carryme`. It must be exactly this.
3. **App nickname:** CarryMe.
4. **Debug signing certificate SHA-1:** paste
   `70:0D:E2:70:73:A9:CD:6F:B2:D7:17:58:38:54:81:72:82:AA:15:52`
5. Click **Register app**, then **Download google-services.json**. Keep this file.
6. Skip the remaining "add SDK" steps (the code already handles them) and click **Continue to console**.
7. Open ⚙️ **Project settings** › **General** › your Android app › **Add fingerprint**, and add the SHA-256 too:
   `B5:2E:61:88:7B:A9:54:4A:88:6A:51:64:89:BF:32:F6:60:06:2C:49:62:38:9F:66:8A:69:E2:84:A6:C2:91:A2`

These fingerprints belong to the CarryMe signing key in `ANDROID_KEYSTORE_BASE64.txt`, which is sent separately and is **not** in this repository. Keep that file private.

## 3. Turn on phone sign-in

1. **Build › Authentication › Get started**.
2. **Sign-in method** tab › **Phone** › **Enable** › **Save**.
3. Still on the Phone provider, open **Phone numbers for testing** and add two test accounts:

   | Phone number | Code | Use for |
   |---|---|---|
   | +231 770 000 001 | 123456 | Rider phone |
   | +231 770 000 002 | 123456 | Driver phone |

   Test numbers never send an SMS, so you can test without paying anything.
4. **Real SMS codes need the Blaze (pay-as-you-go) plan.** Each SMS is charged by Google. Upgrade under **⚙️ › Usage and billing** when you are ready for real users, and set a budget alert.
5. Optional: **Authentication › Settings › SMS region policy** › allow only **Liberia** to block SMS abuse from other countries.

## 4. Create the database

1. **Build › Firestore Database › Create database**.
2. Choose **Start in production mode**.
3. Location: **europe-west1 (Belgium)** is a good choice for Liberia. **You cannot change this later.**
4. When it opens, go to the **Rules** tab. Delete everything there, paste the full contents of `firestore.rules` from this repository, and click **Publish**.

No indexes are needed.

## 5. Add two secrets to GitHub

In your GitHub repository: **Settings › Secrets and variables › Actions › New repository secret**.

| Name | Value |
|---|---|
| `GOOGLE_SERVICES_JSON` | Open `google-services.json` in a text editor and paste **everything**, from the first `{` to the last `}` |
| `ANDROID_KEYSTORE_BASE64` | Paste the entire contents of `ANDROID_KEYSTORE_BASE64.txt` (one long line) |

## 6. Build and install

1. **Actions › Build Android APK › Run workflow** (or push any change).
2. In the build log, the **Configure Firebase** step should say `Firebase configured for project '…'`.
3. Download **CarryMe-apk** and install it.
   If an older demo CarryMe is already on the phone, **uninstall it first**. It was signed with a different key, so the new one can't install over it.

## 7. Approve your first driver

Drivers can't take rides until you approve them. Only you can do this, in the console.

1. On the driver phone, sign in, choose **Drive & earn**, and fill in **My vehicle** (type, model, plate, colour).
2. In Firebase: **Firestore Database › Data › drivers ›** (the driver's document).
3. Click the `approved` field, change it from `false` to `true`, and click **Update**.
4. The driver's app unlocks the **Go online** button straight away.

Check the driver's vehicle type: they only receive requests for that type (e.g. a `keke` driver gets keke requests only).

## 8. Test a full ride (you need two phones)

1. **Phone A (rider):** log in with +231 770 000 001. Book a ride with the same vehicle type as your driver.
2. **Phone B (driver):** log in with +231 770 000 002 as a driver and tap **Go online**. The request appears within a few seconds. Tap **Accept**.
3. Phone A shows the driver, plate and live position. Tap through **I've arrived** on phone B.
4. The rider reads their 4-digit PIN to the driver. The driver enters it to **start the trip**. A wrong PIN is rejected by the database itself.
5. **Complete trip** on phone B. Phone A shows the receipt and rating screen.

You can watch each ride appear and change in **Firestore › Data › rides**.

---

## Troubleshooting

| Message or problem | Fix |
|---|---|
| "This app build is not registered with Firebase" | The SHA-1 / SHA-256 from step 2 are missing, or the `ANDROID_KEYSTORE_BASE64` secret isn't set. The "Show signing fingerprints" step in the build log shows the key that was used; it must match. |
| "SMS sign-in needs the Firebase Blaze plan" | Use a test number from step 3, or upgrade to Blaze. |
| "Phone sign-in is not switched on" | Enable the Phone provider (step 3). |
| Build log says "building in DEMO mode" | The `GOOGLE_SERVICES_JSON` secret is missing or misspelled. |
| "No Android app with package name lr.carryme.carryme" | The Android app was registered with a different package name. Add a new Android app with exactly `lr.carryme.carryme`. |
| Driver never sees requests | Check that `approved` is `true`, the vehicle types match, the driver is online, and the request is less than 5 minutes old and within 15 km. |
| "Missing or insufficient permissions" | The rules from `firestore.rules` weren't published (step 4). |
| Rider's request is cancelled after 3 minutes | No approved driver of that type accepted it in time. |

## How the data is organised

```
users/{uid}          name, phone, lastRole               only the user can read or write
drivers/{uid}        name, phone, approved, vehicleType, vehicleModel, plate,
                     colorName, rating, trips, online, lat, lng
rides/{rideId}       riderId, riderName, riderPhone, pickup, destination, vehicle,
                     seats, payment, fareLrd, distanceKm, durationMin, note,
                     status, driverId, driver details, driverLat, driverLng,
                     timestamps, cancelReason, cancelledBy, riderRating, tipLrd
rides/{rideId}/secret/pin    the ride PIN (rider only)
```

Ride status goes `searching → accepted → arrived → in_progress → completed`, or `cancelled`.

## Still simulated in live mode (next steps)

- **Wallet top-ups and mobile money:** need merchant accounts with Orange Money and MTN MoMo, plus a server (Cloud Functions, Blaze plan) to receive the payment confirmations.
- **Driver document uploads:** need Firebase Storage. For now, check documents in person and then set `approved`.
- **Ride alerts when the driver app is closed:** need push notifications (Firebase Cloud Messaging plus a Cloud Function). Today, drivers must keep the app open while online.
- **Average driver ratings and trip counts:** need a Cloud Function. Each rider's rating is already saved on the ride.
- **Fares are calculated on the rider's phone.** The driver sees the fare before accepting. Before scaling up, have a Cloud Function check fares on the server.
- **Admin dashboard:** for approving drivers and handling support without using the Firebase console.

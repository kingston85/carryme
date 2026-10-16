# CarryMe 🇱🇷 — ride-hailing built for Liberia

An Uber-style Android app (Flutter) for booking **pen-pen, keke, shared taxi seats, taxis and comfort cars** in Monrovia and across Liberia, with prices in **L$ and US$** and payment by **cash, Orange Money, MTN MoMo or an in-app wallet**.

This repository is a complete, working **demo build**: every screen works and rides are simulated on the phone, so you can install it today, show it to partners and investors, and then connect a real backend (see *Going live* below).

---

## Get the APK with GitHub (no computer setup needed)

1. Create a new repository on GitHub (for example `carryme`). It can be private.
2. Upload **everything in this folder** to the repository (drag-and-drop on github.com works, or use `git push`). Make sure the hidden `.github` folder is included.
3. Open the **Actions** tab. The **Build Android APK** workflow starts on every push (or click **Run workflow**).
4. When it finishes (about 8–12 minutes the first time), open the run and download **CarryMe-apk** under *Artifacts*.
5. Unzip it, copy `app-release.apk` to an Android phone and open it. Allow "Install unknown apps" when asked.

Demo login: any name, any valid Liberian number (e.g. `0777 123 456`), code **123456**.

If a build fails, open the failed step in Actions, copy the red error lines, and send them back for a fix.

## Run on your own computer (optional)

```bash
flutter create --platforms=android --org lr.carryme --project-name carryme .
python3 tool/patch_android.py
flutter pub get
flutter run
```

---

## Features

**Rider**
- Map home screen with your GPS location and a big "Where to?" bar
- Search that understands Liberian landmarks (Red Light, ELWA Junction, Duala, RIA…) plus OpenStreetMap places in Liberia
- Drop-a-pin pickup for places without street names, labelled "Near …" the closest landmark
- Five ride types with upfront prices in L$ and US$, pickup ETAs and seat booking for shared taxis
- Real road routes and Monrovia-traffic-adjusted trip times (falls back to an estimate when offline)
- Pay with Cash (L$), Cash (US$), Orange Money, MTN MoMo or CarryMe Wallet
- Promo codes, referral code sharing on WhatsApp, notes to the driver, scheduled rides up to 7 days ahead (e.g. early RIA flights)
- Live trip: driver details, number plate, moving car on the map, ETA, call / SMS driver
- **Ride PIN** so you never enter the wrong vehicle; **Share trip** on WhatsApp/SMS; **SOS** to call emergency or alert trusted contacts
- Ratings, compliments, tips, receipts, trip history, "book again"
- Wallet with Orange Money / MTN MoMo top-up
- Settings: show prices in L$, US$ or both; data saver for slow connections

**Driver**
- Go online/offline, incoming ride offers with a 15-second countdown, fare, payment type and earnings after service fee
- Navigate to pickup/drop-off in Google Maps, PIN check before starting, cash-collection reminder
- Earnings (today / 7 days), cash out to mobile money, trip history
- Document checklist (licence, national ID, registration, insurance, police clearance, photos) and vehicle setup

**Built for Liberia**
- Fares rounded up to the nearest L$5 for easy cash payment
- Rain surcharge for rainy-season downpours, night fare, airport fee for RIA
- Pen-pen blocked in a configurable central-Monrovia zone; pen-pen and keke hidden on long-distance trips
- +231 phone format with Orange / Lonestar Cell MTN detection
- OpenStreetMap maps — no Google Maps API key or billing account needed

---

## Change prices, rates and rules

Everything business-related is in **`lib/config/app_config.dart`**:

| Setting | What it does |
|---|---|
| `lrdPerUsd` | Exchange rate for US$ prices (placeholder **190** — update it) |
| `fares` | Base, per-km, per-minute and minimum fare in L$ for each vehicle (placeholders — set from market research) |
| `rainSurcharge`, `nightSurcharge`, `airportFeeLrd` | Surcharges |
| `commissionRate` | Your cut of each fare (15%) |
| `motorbikeRestrictedZones` | Where pen-pen can't pick up or drop off |
| `promoCodes` | Discount codes |
| `emergencyNumber`, `supportPhone`, `supportWhatsApp` | **Replace with real numbers before launch** |

Landmarks are in `lib/data/liberia_places.dart` (coordinates are approximate — check them and add more).

## Project layout

```
lib/
  config/      app_config.dart – prices, rates, zones, contacts
  data/        Liberian landmarks, demo drivers
  models/      Place, Ride, Driver, User, Payment, VehicleType
  services/    fares, routing (OSRM), place search (Nominatim), GPS, money formatting
  state/       AppState (account, settings, history), RideController, DriverController
  screens/     auth/, rider/, driver/
  widgets/     map widget and shared UI
tool/patch_android.py         adds permissions + app name to the Android project
.github/workflows/build-apk.yml   builds the APK on GitHub
```

---

## Going live — what the demo still needs

The demo simulates drivers on the phone. To run a real service you need:

1. **Backend + real-time dispatch** — e.g. Firebase (Auth, Firestore, Cloud Functions) or your own server. Riders write a ride request; nearby online drivers receive it; status updates stream back. Replace the timers in `RideController` and `DriverController` with these calls.
2. **Phone verification** — replace the demo code `123456` with real SMS OTP (Firebase phone auth, or an SMS gateway that delivers reliably on Orange and Lonestar MTN).
3. **Mobile money** — merchant accounts and APIs with Orange Money Liberia and MTN MoMo, called from your server (never from the app).
4. **Maps at scale** — the free OpenStreetMap tile, OSRM and Nominatim servers are for testing only. Use a paid provider (e.g. MapTiler, Stadia, Mapbox) or self-host before launch.
5. **Admin dashboard** — approve drivers' documents, set fares and the exchange rate, handle support and refunds.
6. **Play Store release** — create an upload keystore, sign the release build, and publish an app bundle (`flutter build appbundle`).
7. **Licensing & insurance** — confirm requirements for commercial transport and motorcycle taxis with the relevant Liberian authorities before you operate.

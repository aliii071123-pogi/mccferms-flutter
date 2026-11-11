# MCC FERMS Flutter

Flutter client for the Mabalacat City College Facility and Equipment Reservation Management System. All FERMS data is accessed through the Laravel API; this app does not connect to Supabase directly.

## Configure

Set `API_BASE_URL` in the ignored `config/app.json` to the Laravel server origin. Copy `config/app.example.json` as a starting point. Never put database credentials or Supabase service-role keys in Flutter configuration.

For local development on the same computer, `http://localhost:8000` works only when Laravel is running there. In a remote dev container or Codespace, a browser's `localhost` refers to the computer running the browser, not the container. Start Laravel with its port exposed/forwarded and use the API's forwarded URL, or use a deployed API URL. The API server must be running and reachable before Microsoft sign-in can open.

The API contract is documented in [docs/flutter-api.md](docs/flutter-api.md). Mobile Microsoft sign-in opens the Laravel sign-in route in the system browser, exchanges the one-time callback code, and stores the returned bearer token using secure storage. Register `mccferms://auth/callback` with the native application and configure the matching Laravel callback URI. For Flutter Web, configure an HTTPS callback back to the deployed app origin; the app reads the returned `code` query parameter and does not request the mobile callback flow.

## Run

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=config/app.json
```

Run the test suite with `flutter test`. Android and iOS runners register the `mccferms://auth/callback` scheme. Production releases still need the institution's signing identifiers and verified universal/app links.
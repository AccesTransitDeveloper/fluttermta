# Driver app

## Clone and run

```sh
git clone https://github.com/AccesTransitDeveloper/fluttermta.git
cd fluttermta
flutter doctor
flutter pub get
```

Use a Flutter SDK compatible with `pubspec.yaml` (Dart 3.10 or later).
Android requires Android SDK; iOS requires macOS, Xcode and CocoaPods.
Configure Firebase for your application ID and restricted native Maps keys
using the existing platform examples/local configuration. Never commit local
credentials.

For an existing clone, use `git pull --ff-only origin main`, then
`flutter pub get`. Keep local changes if Git reports a conflict.

## MTA API configuration

The MTA integration uses the Core driver's bearer token and requires an API
base URL at build/run time. Set `MTA_API_BASE_URL` with Flutter's
`--dart-define`; use the deployment-specific MTA driver-app API base URL (the
base path should include `/api/mta/driver-app`). Do not put a production URL or
credentials in source code.

```sh
export MTA_API_BASE_URL="https://your-api-host.example/api/mta/driver-app"
flutter run --dart-define="MTA_API_BASE_URL=${MTA_API_BASE_URL}"
flutter build appbundle --dart-define="MTA_API_BASE_URL=${MTA_API_BASE_URL}"
```

Replace the example host with the deployment's actual URL. If the define is
missing or invalid, MTA requests are unavailable and the app will report that
configuration error. Supply the same define for each build flavor/environment.

## New-driver document handoff

New signups keep native identity checks, terms, password and OTP. Only after
Core confirms account creation and authentication does the app open
`https://fashnmall.com/at-driver-web/onboarding`.

The trusted server verifies the driver account. Flutter sends its authorization
only in an HTTPS header; the WebView receives a single-use handoff through the
JavaScript bridge, never the account token or CRM key. Name/contact come from
the verified account, and Flutter provides the selected language.

The hosted page submits original photos/PDFs through a server to CRM. The CRM
application ID is stored separately from the operational Core account ID.
Completion is rechecked server-side before returning Home; it does not imply
Core document approval or MTA readiness. Pending registration resumes on Home,
including after a signup requiring a separate sign-in.

**This repository update does not deploy the website or its backend.** Before
using the new registration flow, publish the updated onboarding page and its
dedicated `/api/driver-onboarding` service on `fashnmall.com`. The service is in
the web workspace at `artifacts/at-driver-web/server-entry.ts`; it requires
server-only `DATABASE_URL` and `DRIVER_APPLICATION_API_KEY`. Until that protocol
is deployed, registration may report that the service is unavailable. Never
place the CRM key in Flutter or bypass server verification.

The old native AI registration screen is removed. Existing local draft files
are not deleted: Documents retains its authenticated Core upload/retry helpers
for previously saved files. Native MTA configuration, authorization/readiness
checks and document approval logic are unchanged.

The Core admin page at `https://admin.accessibletransit.com/users/driver`
belongs to an external service, not this repository. Its queue, required
document metadata, and actual approval transition cannot be verified here
without an authorized test driver/admin account. Before using this flow in
production, register a disposable driver in a Core **test environment**,
check every required document type and metadata field in the Core response,
verify each upload appears in the authorized admin queue, approve/reject
there, and confirm the driver app and MTA readiness both reflect the result.
Do not use live driver documents or create test accounts in production.

## Verification

```sh
flutter analyze
flutter test test/hosted_onboarding_preferences_test.dart
flutter test test/auth_token_persistence_test.dart
flutter test test/ai_driver_submission_test.dart
flutter test test/server_config_test.dart
```

Native compilation and real-device WebView permissions/file-picker checks
require platform SDKs. They were not available in the implementation workspace;
the update was checked for relative imports, route integration and preserved
MTA/Core files, not claimed as a device-tested release.

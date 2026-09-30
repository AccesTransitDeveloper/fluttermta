# Driver app

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

AT AI Driver saves the checklist and photos locally under the registration
email/phone identity. It creates the account through Core first, then uses
Core's authenticated `GET uploaded_document` and multipart
`PUT uploaded_document/{documentId}` routes to send matching files. A Core
response acknowledging an upload does **not** prove admin approval. The
Documents screen shows each local file's submission progress and refreshes
Core's `auth/driver/information_status`; any unsubmitted files can be retried
after signing back in to the same account. If Core does not expose a matching
document type, or requires an expiry date/unique code, the app stops that
upload with an explicit message rather than guessing an ID or silently
claiming the file was sent. Those fields must be completed using the Core
Documents editor. Vehicle documents may require vehicle registration first.

The Core admin page at `https://admin.accessibletransit.com/users/driver`
belongs to an external service, not this repository. Its queue, required
document metadata, and actual approval transition cannot be verified here
without an authorized test driver/admin account. Before using this flow in
production, register a disposable driver in a Core **test environment**,
check every required document type and metadata field in the Core response,
verify each upload appears in the authorized admin queue, approve/reject
there, and confirm the driver app and MTA readiness both reflect the result.
Do not use live driver documents or create test accounts in production.

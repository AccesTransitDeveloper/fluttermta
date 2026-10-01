# MTA driver API

The Flutter build's base URL is:

```text
https://mta-accessibletransit.com/api/mta/driver-app
```

```bash
flutter build apk --dart-define="MTA_API_BASE_URL=https://mta-accessibletransit.com/api/mta/driver-app"
```

Every request requires `Authorization: Bearer <Core driver login token>`.
POST requests use `Content-Type: application/json`.
There is no separate MTA login/token and no admin session is needed.
Never put broker tokens or admin credentials into Flutter.

| Method | Path relative to base URL | Purpose |
| --- | --- | --- |
| GET | `/status` | MTA consent, eligibility and active trip/offer state |
| POST | `/consent` | Enable/disable MTA; register the Core-authenticated driver |
| POST | `/location` | Send online GPS and availability, or mark offline |
| GET | `/offers` | Retrieve this driver's current unexpired offers |
| POST | `/offers/{tripId}/accept` | Accept this driver's offer |
| POST | `/offers/{tripId}/reject` | Reject this driver's offer and try another driver |

Consent payload:

```json
{
  "accepted": true,
  "termsVersion": "mta-driver-consent-v1",
  "driver": {
    "name": "Driver name",
    "phone": "Driver phone",
    "vehicle": "Selected vehicle",
    "plateNumber": "Optional plate",
    "tlcLicenseNumber": "Optional TLC license"
  }
}
```

Online location payload (timestamp must be the real, recent UTC sensor fix):

```json
{
  "lat": 40.7,
  "lng": -73.9,
  "timestamp": "<actual GPS fix time in ISO 8601 UTC>",
  "online": true,
  "available": true
}
```

Offline payload: `{"online":false,"available":false}`.
Accept/reject payload: `{}`; use the trip ID returned by `/offers`.
Flutter also sends `Idempotency-Key: mta-{offerId}-accept` (or `-reject`).

Automatic matching uses **2 straight-line miles** from pickup to driver.
Driver consent, Core document readiness, online/available state, and fresh
GPS are required. Drivers with an active trip/offer are not matched again.
Offers expire after 30 seconds. Flutter polls every 8 seconds while it can
run; delivery in a suspended/terminated app is not guaranteed push delivery.
Accepted by MTA does not necessarily mean confirmed by the broker: inspect
the returned `partnerConfirmationStatus`.

## Verify after publishing

An unauthenticated `GET /api/mta/driver-app/status` must return HTTP 401:

```json
{"error":"A Core bearer token is required"}
```

`Unauthorized — please log in` is an admin-session response and indicates
the live driver routes are not using the intended driver authentication.
Never remove authentication to work around this. Workspace changes and
Flutter/GitHub updates do not update the published backend: publish the
current backend before testing the public URL again.

A Core outage returns HTTP 503, not successful driver authentication.
Verification with a real device is still needed for the complete
GPS → offer → accept/reject flow.

## Regression checks

Run from the workspace root:

```bash
NODE_ENV=production pnpm --filter @workspace/scripts exec tsx --test ../artifacts/api-server/test/*.test.ts
pnpm --filter @workspace/api-server run typecheck
pnpm --filter @workspace/api-server run build
```

Tests do not use real driver tokens, modify driver/trip data, or contact
brokers. Driver-auth tests stub Core responses, so their passing does not
prove the real Core service is reachable.
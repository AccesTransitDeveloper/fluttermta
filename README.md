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

## Local platform configuration

Signing and Firebase configuration files are intentionally not included in this repository.
Copy the provided Firebase `.example` files to `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` and configure your own Firebase project.
For Android signing, create `android/keystore.properties` and supply your own keystore
file locally; never commit the keystore or its passwords. The current Android Gradle
configuration requires a signing config even for debug builds.

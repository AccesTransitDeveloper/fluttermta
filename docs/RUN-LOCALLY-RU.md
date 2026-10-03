# Как запустить полное приложение водителя

Репозиторий: https://github.com/AccesTransitDeveloper/fluttermta  
Ветка: `main`.

Здесь находится весь исходный код мобильного приложения: экраны, авторизация,
интеграции, Android/iOS, ресурсы и тесты. Это исходники, не готовый APK.
Серверы Core, MTA и веб-регистрации не запускаются командой `flutter run`.

## 1. Подготовьте компьютер

- Установите Git и Flutter с Dart 3.10 или новее, совместимый с `pubspec.yaml`.
- Для Android установите Android Studio, Android SDK и совместимый JDK.
- Для iOS нужен Mac с Xcode и CocoaPods.
- Подключите телефон или запустите эмулятор. Разрешите USB debugging на Android.

```sh
git clone https://github.com/AccesTransitDeveloper/fluttermta.git
cd fluttermta
flutter doctor
flutter pub get
flutter devices
```

Исправьте ошибки нужной платформы, которые показывает `flutter doctor`.

## 2. Настройте Firebase локально

Приложение вызывает `Firebase.initializeApp()` при старте. Без настоящей
платформенной конфигурации Firebase запуск не завершится успешно.

Используйте конфигурацию вашего действующего проекта Firebase с идентификаторами
приложения, указанными в Android Gradle и iOS Xcode:

- Android: сохраните файл конфигурации в `android/app/google-services.json`.
- iOS: сохраните файл конфигурации в `ios/Runner/GoogleService-Info.plist`.

Эти файлы исключены из Git намеренно. Пример `.example` не заменяет рабочую
конфигурацию. Не загружайте реальные локальные настройки или ключи в репозиторий.

## 3. Настройте карты

- Android: задайте ограниченный Android Maps key через `GOOGLE_MAPS_API_KEY`
  в окружении процесса сборки либо одноимённое свойство в `android/local.properties`.
  Не удаляйте из этого файла существующие пути Android/Flutter SDK.
- iOS: скопируйте `ios/Flutter/Secrets.xcconfig.example` в локальный
  `ios/Flutter/Secrets.xcconfig` и укажите ограниченный iOS Maps key.
  Не коммитьте этот локальный файл.
- Если серверная конфигурация выбирает Mapbox, дополнительно передайте
  `--dart-define=MAPBOX_ACCESS_TOKEN=...` с вашим клиентским Mapbox-токеном.

Ограничьте клиентские ключи/токены нужными SDK и идентификаторами приложений.
Не заменяйте существующий выбор карт ради запуска.

## 4. Запустите приложение

Для MTA нужен реальный адрес развёрнутого driver-app API. Пример ниже содержит
заглушку: замените `your-api-host.example` вашим сервером. Не используйте адрес
страницы регистрации как адрес MTA.

```sh
flutter run --dart-define=MTA_API_BASE_URL=https://your-api-host.example/api/mta/driver-app
```

Если подключено несколько устройств, добавьте `-d DEVICE_ID` из `flutter devices`.
Без действующего MTA API приложение не сможет получать MTA-заказы; отсутствие
настройки не исправляется открытием веб-регистрации.

Для iOS сначала проверьте подпись приложения в Xcode:

```sh
open ios/Runner.xcworkspace
```

Выберите свою команду подписи и устройство, затем запускайте через Flutter.

## 5. Соберите Android APK для локальной проверки

Debug APK не требует вашего production-ключа подписи:

```sh
flutter build apk --debug --dart-define=MTA_API_BASE_URL=https://your-api-host.example/api/mta/driver-app
```

Результат: `build/app/outputs/flutter-apk/app-debug.apk`.
Это локальная тестовая сборка, не подписанный релиз для Google Play.

## 6. Как проверить последние исправления регистрации

Flutter открывает ровно этот адрес, только для регистрации водителя:

https://fashnmall.com/at-driver-web/onboarding

Веб-страница и её сервер находятся в отдельном репозитории:

https://github.com/AccesTransitDeveloper/Transit-Assistant-AI

Они должны быть опубликованы на существующем домене. Сборка Flutter сама по себе
не публикует сайт и не обновляет его сервер. Не меняйте основной API, MTA или
адрес всего приложения на этот регистрационный URL.

Проверка доступности сервиса без отправки документов:

```sh
curl -i https://fashnmall.com/at-driver-web/onboarding/api/health
```

Ожидается HTTP 200, `service: "at-driver-onboarding"`, `protocolVersion: 1`,
`crmConfigured: true` и `databaseConfigured: true`. Эти флаги подтверждают наличие
настроек, но не заменяют проверку реальной отправки в CRM.

Открывайте регистрацию из приложения после входа: отдельный браузер не получает
авторизацию водителя автоматически. CRM-ключ и `DATABASE_URL` нужны только
серверу; никогда не добавляйте их во Flutter.

## Проверки и ограничения

```sh
flutter analyze
flutter test test/hosted_onboarding_preferences_test.dart
flutter test test/auth_token_persistence_test.dart
flutter test test/ai_driver_submission_test.dart
flutter test test/server_config_test.dart
```

В среде реализации не было Flutter/Android/iOS SDK, поэтому нативная сборка и
полный сценарий на устройстве пока не подтверждены. Проверка регистрации должна
проходить с разрешённой тестовой учётной записью и в тестовом окружении:
не создавайте тестовые заявки с настоящими документами в production.
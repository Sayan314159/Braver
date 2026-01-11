# Braver Mobile

This directory contains a Flutter-based mobile browser that supports ad-free media playback and background audio playback on Android and iOS.

## Files

- `lib/main.dart` – initializes the WebView with ad-blocking and background playback settings. It loads YouTube by default and uses the `adblocker` package to filter ads.
- `android/app/src/main/java/com/example/bravermobile/MainActivity.kt` – overrides `onPause()` to prevent the default WebView pause when the app goes to the background, so audio continues playing. You may need to implement a foreground service for fully smooth background playback.
- (You will need to create iOS modifications, including enabling the Audio background mode in Xcode and updating `Info.plist` as described in the main design document.)

## Building the app

1. Install Flutter and the Flutter SDK (https://flutter.dev).
2. Clone this repository and navigate to the `braver_mobile` directory.
3. Run `flutter pub get` to install dependencies.
4. Use `flutter run` to build and deploy the app to an emulator or device. On Android, ensure you run with `--release` mode for best performance.
5. For iOS, open `ios/Runner.xcworkspace` in Xcode and enable the **Audio** background mode in the Signing & Capabilities tab. Add the `UIBackgroundModes` `audio` entry to `Info.plist` as shown in the design document.
6. Test YouTube and Spotify playback; media should start without ads and continue playing when you minimize the app or lock the screen.

Refer to `mobile_browser_design.md` for more details on how the system works.

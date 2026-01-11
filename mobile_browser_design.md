# Mobile Browser Design for Ad‑Free & Background Playback

## Goals

The user would like a mobile browser that satisfies two main requirements:

1. **Ad‑free media playback**: Videos and music from YouTube, Spotify and other sites should play without advertisements.  
2. **Background/locked‑screen playback**: Audio should continue playing smoothly when the application is minimized or the device is locked.

On desktop platforms the Brave browser already offers these features, but the mobile version only provides ad‑blocking.  This document outlines a design for a custom mobile browser that brings both ad‑free playback and uninterrupted background playback to Android and iOS devices.

## Research Insights

### Existing Solutions

* **Bromite (Android)** – Bromite is an open‑source Chromium fork with a built‑in ad‑blocking engine.  The project’s feature list notes that it can *“allow playing videos in background tabs and disable pause on switching tabs”*【804525780781851†L408-L414】.  This means the browser does not automatically pause video or audio when the user switches away from the active tab.  Bromite is Android‑only and focuses on privacy; its ad‑blocker uses EasyList/EasyPrivacy rules【804525780781851†L408-L414】.
* **Brave (Android/iOS)** – Brave’s mobile browser integrates an ad blocker but deliberately pauses media when the app is backgrounded, so it does not meet requirement 2.  It is closed‑source, so modifications are not easily integrated.
* **Flutter `webview_flutter`** – The Flutter community provides a cross‑platform `WebView` widget that can load arbitrary websites.  The package supports setting platform‑specific parameters.  For example, the Android implementation exposes `setMediaPlaybackRequiresUserGesture(false)`, which allows media to begin playing without a user gesture【12629587368952†L146-L165】.  For iOS, `allowsInlineMediaPlayback` and `mediaTypesRequiringUserAction` can be configured【12629587368952†L146-L165】.  These settings are important for allowing videos or audio to start automatically, but the package does not handle background playback out of the box.

### Challenges and Considerations

1. **Ad‑blocking** – Effective ad‑blocking on YouTube and Spotify requires filtering network requests.  EasyList/EasyPrivacy provide community‑maintained filter lists that are used by many browsers.  Implementing an ad‑blocker involves intercepting requests in the WebView and dropping or redirecting those that match blocked domains or URL patterns.
2. **Background playback** – Android and iOS treat WebViews differently when an app is backgrounded.  On Android, the `Activity` lifecycle typically calls `webView.onPause()` in `onPause()`, which stops HTML5 media playback.  Overriding this behaviour or running the WebView inside a foreground `Service` can keep playback alive.  Bromite’s patches effectively remove the pause call and add a `#resume-background-video` flag【804525780781851†L408-L414】.  On iOS, background audio requires enabling the **Audio** background mode in the app’s capabilities and configuring the `WKWebView` to continue playing audio.
3. **Spotify & YouTube DRM** – Spotify and YouTube use protected content that is subject to platform DRM policies.  The browser must request media playback permission and handle audio focus properly.  This design assumes users have the right to play this content but does not circumvent any DRM restrictions.

## Proposed Architecture

### Technology Stack

1. **Cross‑platform framework:** Use Flutter to build a single codebase for Android and iOS.  Flutter’s `webview_flutter` plugin provides the WebView widget and exposes platform‑specific controls.
2. **Ad‑blocking engine:** Integrate an ad‑blocker based on EasyList/EasyPrivacy rules.  A Dart package such as [`adblocker`](https://pub.dev/packages/adblocker) can parse filter lists and evaluate requests.  The WebView’s request interceptor (`NavigationDelegate.onNavigationRequest`) is used to cancel requests that match the ad‑block rules.
3. **Background playback:** Implement platform‑specific code to keep media playing:
   * **Android** –
     - Override the `onPause()` method of the activity so that it does **not** call `webView.onPause()` when the app goes to the background.  
     - Use a **foreground service** (with the `mediaPlayback` type) to host the WebView when playback begins.  The service continues running even when the main activity is minimized, and it creates a notification so the user can pause or stop playback.  
     - Set `setMediaPlaybackRequiresUserGesture(false)` on the `AndroidWebViewController` to allow automatic media playback【12629587368952†L146-L165】.
   * **iOS** –
     - Enable **Audio** in the *Background Modes* capability in Xcode.  
     - Set `allowsInlineMediaPlayback: true` and `mediaTypesRequiringUserAction: {}` on the `WebKitWebViewControllerCreationParams` so that media can start playing inline without a user gesture【12629587368952†L146-L165】.  
     - Ensure the app’s `Info.plist` includes the `UIBackgroundModes` array with `audio`.
4. **Persisting playback when the screen is locked:** Both Android and iOS will pause audio if the WebView is not in the foreground unless the app has active audio or a foreground service.  The above approach with a foreground service (Android) and background audio mode (iOS) addresses this.

### High‑Level Workflow

1. **Load filter lists** – On startup, download or bundle EasyList/EasyPrivacy filter lists.  Parse them using the chosen ad‑block library.
2. **Initialize WebView** – Create a `WebViewController` with platform‑specific settings (disable the requirement for user gesture to start media, allow inline playback, etc.)【12629587368952†L146-L165】.  Set up a `NavigationDelegate` to intercept all resource requests.
3. **Intercept requests** – For each request, check the URL against the ad‑block filter lists.  If it matches, cancel the request or return a blank response.  Otherwise, allow navigation.
4. **Detect media playback** – When the user starts playing media (e.g., clicking play on a YouTube or Spotify page), create or promote a foreground service (Android) or ensure background audio is enabled (iOS).  Use media metadata to display a notification.
5. **Handle lifecycle events** –
   * **onPause()**: do **not** call `webView.onPause()`.  Instead, keep the WebView alive in a foreground service so audio continues.  
   * **onDestroy()**: properly tear down the WebView and stop the foreground service.

## Code Skeleton

Below is a simplified code skeleton for a Flutter‑based implementation.  It shows how to initialize the WebView with ad‑blocking and background playback support.  This code is illustrative – real implementation would require additional error handling, UI polish and integration with Android/iOS project files.

```dart
// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:adblocker/adblocker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BraverApp());
}

class BraverApp extends StatefulWidget {
  const BraverApp({super.key});

  @override
  State<BraverApp> createState() => _BraverAppState();
}

class _BraverAppState extends State<BraverApp> {
  late final WebViewController _controller;
  AdBlockEngine? _engine;

  @override
  void initState() {
    super.initState();
    _initAdBlocker();
    _initWebView();
  }

  Future<void> _initAdBlocker() async {
    // Load filter lists from assets or network.
    final easyList = await DefaultFilterLists().easyList();
    final easyPrivacy = await DefaultFilterLists().easyPrivacy();
    _engine = await AdBlockEngine.create(
      [easyList, easyPrivacy],
    );
  }

  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            // Block ads using the ad‑block engine.
            if (_engine != null && await _engine!.matches(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.youtube.com'));

    // Android‑specific: disable the requirement for user gesture to start media.
    if (_controller.platform is AndroidWebViewController) {
      ( _controller.platform as AndroidWebViewController )
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Braver Mobile',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Braver Mobile'),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
```

### Android Native Overrides

To keep audio playing when the app is minimized, the Android `Activity` should not call `webView.onPause()` on `onPause()`.  The snippet below shows how you could override the default behaviour in Kotlin:

```kotlin
// android/app/src/main/java/com/example/bravermobile/MainActivity.kt
package com.example.bravermobile

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onPause() {
        // Do NOT call super.onPause() here.  This avoids calling webView.onPause(),
        // allowing background media playback to continue.
    }
}
```

For continuous playback even when the screen is locked, you should move playback into a **foreground service** using a platform channel.  The service should declare `android:foregroundServiceType="mediaPlayback"` in the manifest and create a media notification.

### iOS Configuration

1. In Xcode, open your project’s `.xcworkspace` and select your app target.  Under **Signing & Capabilities**, add the **Background Modes** capability and check **Audio, AirPlay and Picture in Picture**.  
2. In your `Info.plist`, add:

   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
   </array>
   ```

This allows the `WKWebView` to continue playing audio when the app goes to the background or the device is locked.

### Ad‑Block Filter Updates

Filter lists change frequently.  You can bundle the initial lists with the app and periodically download updates from EasyList/EasyPrivacy.  The ad‑block engine should reload the rules without requiring an app restart.

## Next Steps

1. **Repository integration** – Clone your GitHub repository (e.g. `Sayan314159/Braver`) and add the Flutter project within a new directory such as `braver_mobile/`.  Add the above files (`lib/main.dart`, Android native overrides, iOS configuration, and a `README.md` explaining how to build the app).  Commit and push the changes.  This environment currently only provides read‑only GitHub APIs, so you will need to perform the push from a system with GitHub write access.
2. **Testing on devices** – Build the Flutter project for Android and iOS.  Install it on test devices to verify ad‑blocking and background playback.  You may need to tune the ad‑block filter rules or add exceptions for some domains.
3. **Polish and distribution** – Once the basic functionality works, improve the user interface (tabs, back/forward buttons, bookmarks, dark mode) and release builds through the Google Play Store or Apple App Store subject to their policies.

---

### Citations

* The Bromite project notes that it includes a fast ad‑blocking engine and that it *“allow[s] playing videos in background tabs and disable pause on switching tabs”*【804525780781851†L408-L414】.  This shows that background playback is feasible in a Chromium‑based browser.
* Flutter’s `webview_flutter` plugin demonstrates how to set platform‑specific parameters: on iOS you can allow inline media playback and remove media‑type user‑gesture requirements, and on Android you can disable the requirement for a user gesture before media plays【12629587368952†L146-L165】.  These settings are essential for enabling media to start automatically.

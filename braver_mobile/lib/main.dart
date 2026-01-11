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
            // Block ads using the ad-block engine.
            if (_engine != null && await _engine!.matches(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.youtube.com'));

    // Android-specific: disable the requirement for user gesture to start media.
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
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

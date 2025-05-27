import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class WebViewPage extends StatefulWidget {
  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _webViewController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    print("🔹 WebView Initialized - Waiting for Login Event...");
    _requestPermissions();
    InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && micStatus.isGranted) {
      print("✅ Camera & Mic permissions granted.");
    } else {
      print("❌ Camera or Mic permission denied.");
    }
  }

  Future<void> _setupFirebaseMessaging(String userId, String authToken) async {
    print("🚀 _setupFirebaseMessaging STARTED for userId: $userId");

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print("❌ User denied notification permissions.");
      return;
    }

    print("✅ User granted notification permissions.");

    String? token = await messaging.getToken();
    print("📌 FCM Token: $token");

    if (token != null) {
      await _sendTokenToServer(userId, authToken, token);
    }

    print("🎯 _setupFirebaseMessaging COMPLETED");
  }

  Future<void> _sendTokenToServer(String userId, String authToken, String token) async {
    print("🚀 Sending FCM token to backend for user: $userId");

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceId = "";
      String deviceType = "";

      if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceType = "android";
      } else if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "";
        deviceType = "ios";
      }

      var url = Uri.parse("https://community.wotgonline.com/api/subscriptions/subscribe");
      var response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "userId": userId,
          "deviceId": deviceId,
          "deviceType": deviceType,
          "subscription": {
            "fcmToken": token,
          }
        }),
      );

      if (response.statusCode == 200) {
        print("✅ FCM Token successfully sent to backend!");
      } else {
        print("❌ Failed to send FCM token: ${response.body}");
      }
    } catch (e) {
      print("❌ Error sending FCM token: $e");
    }
  }

  Future<void> _handleRefresh() async {
    if (_webViewController != null) {
      await _webViewController!.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController?.canGoBack() ?? false) {
          _webViewController?.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _handleRefresh,
          child: Column(
            children: <Widget>[
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri("https://community.wotgonline.com/"),
                  ),
                  initialOptions: InAppWebViewGroupOptions(
                    crossPlatform: InAppWebViewOptions(
                      mediaPlaybackRequiresUserGesture: false,
                    ),
                    android: AndroidInAppWebViewOptions(
                      useHybridComposition: true,
                    ),
                    ios: IOSInAppWebViewOptions(
                      allowsInlineMediaPlayback: true,
                    ),
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;

                    controller.addJavaScriptHandler(
                      handlerName: "onLoginSuccess",
                      callback: (args) async {
                        print("🔹 Received login event from ReactJS: $args");

                        if (args.isEmpty || args[0] == null) {
                          print("❌ ERROR: Received empty login data");
                          return;
                        }

                        try {
                          String userId = args[0]["userId"].toString();
                          String name = args[0]["name"].toString();
                          String email = args[0]["email"].toString();
                          String authToken = args[0]["token"].toString();

                          print("✅ User ID: $userId");
                          print("✅ Name: $name");
                          print("✅ Email: $email");
                          print("✅ Token: $authToken");

                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setString("userId", userId);
                          await prefs.setString("name", name);
                          await prefs.setString("email", email);
                          await prefs.setString("authToken", authToken);

                          await _setupFirebaseMessaging(userId, authToken);
                        } catch (e) {
                          print("❌ ERROR: Failed to parse login data - $e");
                        }
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: "playAudio",
                      callback: (args) async {
                        final data = args.first;

                        const platform = MethodChannel("wotg.flutter.audio");
                        try {
                          await platform.invokeMethod("playAudio", {
                            "title": data["title"],
                            "url": data["url"],
                          });
                        } catch (e) {
                          print("❌ Failed to call native audio service: $e");
                        }
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: "playPlaylist",
                      callback: (args) async {
                        final playlist = List<Map<String, dynamic>>.from(args[0]);
                        const platform = MethodChannel("wotg.flutter.audio");

                        try {
                          await platform.invokeMethod("playPlaylist", {
                            "tracks": playlist,
                          });
                        } catch (e) {
                          print("❌ Failed to send playlist to native: $e");
                        }
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: "nextTrack",
                      callback: (_) async {
                        const platform = MethodChannel("wotg.flutter.audio");

                        try {
                          await platform.invokeMethod("nextTrack");
                        } catch (e) {
                          print("❌ Failed to trigger nextTrack: $e");
                        }
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: "previousTrack",
                      callback: (_) async {
                        const platform = MethodChannel("wotg.flutter.audio");

                        try {
                          await platform.invokeMethod("previousTrack");
                        } catch (e) {
                          print("❌ Failed to trigger previousTrack: $e");
                        }
                      },
                    );
                  },
                  onPermissionRequest: (controller, request) async {
                    print("📩 onPermissionRequest: ${request.resources}");
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onConsoleMessage: (controller, message) {
                    print("📦 JS Console: ${message.message}");
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

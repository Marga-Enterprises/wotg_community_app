import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebViewPage extends StatefulWidget {
  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _webViewController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    print("🔹 WebView Initialized - Waiting for Login Event...");
  }

  /// Setup Firebase Cloud Messaging (FCM) and send token to backend
  Future<void> _setupFirebaseMessaging(String userId, String authToken) async {
    print("🚀 _setupFirebaseMessaging STARTED for userId: $userId");

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for push notifications
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ User granted notification permissions.");
    } else {
      print("❌ User denied notification permissions.");
      return;
    }

    // Get Firebase Cloud Messaging (FCM) Token
    String? token = await messaging.getToken();
    print("📌 FCM Token: $token");

    if (token != null) {
      await _sendTokenToServer(userId, authToken, token);
    }
    print("🎯 _setupFirebaseMessaging COMPLETED");
  }

  /// Send FCM token and device info to backend
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
        deviceId = iosInfo.identifierForVendor!;
        deviceType = "ios";
      }

      var url = Uri.parse("https://community.wotgonline.com/api/subscriptions/subscribe");
      var response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken"
        },
        body: jsonEncode({
          "userId": userId,
          "deviceId": deviceId,
          "deviceType": deviceType,
          "subscription": {
            "fcmToken": token
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController?.canGoBack() ?? false) {
          _webViewController?.goBack();
          return false; // Prevent app from exiting
        }
        return true; // Exit if WebView cannot go back
      },
      child: Scaffold(
        body: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _handleRefresh,
          child: Column(
            children: <Widget>[
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri("https://community.wotgonline.com/")),
                  initialOptions: InAppWebViewGroupOptions(
                    crossPlatform: InAppWebViewOptions(),
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    // ✅ Listen for login success from ReactJS
                    controller.addJavaScriptHandler(
                      handlerName: "onLoginSuccess",
                      callback: (args) async {
                        print("🔹 Received login event from ReactJS: $args");

                        if (args.isEmpty || args[0] == null) {
                          print("❌ ERROR: Received empty login data");
                          return;
                        }

                        try {
                          // ✅ Convert all values to String before storing
                          String userId = args[0]["userId"].toString();
                          String name = args[0]["name"].toString();
                          String email = args[0]["email"].toString();
                          String authToken = args[0]["token"].toString();

                          print("✅ User ID: $userId");
                          print("✅ Name: $name");
                          print("✅ Email: $email");
                          print("✅ Token: $authToken");

                          // ✅ Save user authentication data in SharedPreferences
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setString("userId", userId);
                          await prefs.setString("name", name);
                          await prefs.setString("email", email);
                          await prefs.setString("authToken", authToken);

                          // ✅ Call Firebase Messaging Setup
                          print("🚀 Calling _setupFirebaseMessaging() NOW...");
                          await _setupFirebaseMessaging(userId, authToken);
                          print("🎯 _setupFirebaseMessaging COMPLETED");
                        } catch (e) {
                          print("❌ ERROR: Failed to parse login data - $e");
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_webViewController != null) {
      await _webViewController!.reload();
    }
  }
}

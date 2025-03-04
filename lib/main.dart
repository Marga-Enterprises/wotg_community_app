import 'package:flutter/material.dart';
import 'webview.dart'; // Import your WebViewPage here

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Disable the debug banner
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(5.0), // Set a custom height (default is 56)
          child: AppBar(
            title: Text(" "), // Adjust title if needed
            centerTitle: true,
            backgroundColor: Colors.red, // Customize AppBar color
            elevation: 0, // Remove shadow for a flat design
          ),
        ),
        body: WebViewPage(), // Your WebView page
      ),
    );
  }
}

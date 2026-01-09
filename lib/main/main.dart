import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const AscentionIdleApp());
}

class AscentionIdleApp extends StatelessWidget {
  const AscentionIdleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ascention Idle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

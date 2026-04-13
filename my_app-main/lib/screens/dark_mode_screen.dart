import 'package:flutter/material.dart';

class DarkModeScreen extends StatelessWidget {
  const DarkModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dark Mode')),
      body: const Center(child: Text('Dark Mode Screen')),
    );
  }
}

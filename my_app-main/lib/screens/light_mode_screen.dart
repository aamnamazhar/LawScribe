import 'package:flutter/material.dart';

class LightModeScreen extends StatelessWidget {
  const LightModeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Light Mode')),
      body: const Center(child: Text('Light Mode Screen')),
    );
  }
}

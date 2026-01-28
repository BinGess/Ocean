import 'package:flutter/material.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日记'),
      ),
      body: const Center(
        child: Text('日记页面 - 待实现'),
      ),
    );
  }
}

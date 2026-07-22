import 'package:flutter/material.dart';

class AppStartupLoading extends StatelessWidget {
  const AppStartupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

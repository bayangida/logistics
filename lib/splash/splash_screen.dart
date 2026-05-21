import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final String logoUrl;
  final String title;
  final String subtitle;

  const SplashScreen({
    Key? key,
    this.logoUrl = 'https://dashboard.codeparrot.ai/api/image/Z9ypdCppvFKitUlW/group.png',
    this.title = 'Bayangida',
    this.subtitle = 'Farms',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              logoUrl,
              width: 100, // Adjusted size for better visibility
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

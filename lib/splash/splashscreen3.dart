import 'package:flutter/material.dart';

class Logoscreen extends StatefulWidget {
  const Logoscreen({super.key});

  @override
  _LogoscreenState createState() => _LogoscreenState();
}

class _LogoscreenState extends State<Logoscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/Flow1.gif"),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
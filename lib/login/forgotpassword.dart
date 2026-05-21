import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();

  Future<void> _resetPassword() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text);
      // Show a success message or navigate to a confirmation screen
    } on FirebaseAuthException catch (e) {
      print("Failed to send reset email: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 54), // Space for the status bar
            HeaderComponent(),
            SizedBox(height: 20),
            Text(
              'Forgot Password',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk Variable',
                fontWeight: FontWeight.w800,
                fontSize: 36,
                color: Color(0xFF0B7F40),
                height: 46 / 36,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'No worries! Enter your email address below\nand we will send you a code to reset\npassword.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF475569),
                height: 22 / 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'E-mail',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1E293B),
                  height: 22 / 14,
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                    height: 22 / 14,
                  ),
                ),
              ),
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0B7F40),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Send Reset Instruction',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.21,
                    color: Colors.white,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32), // Space between button and bottom
          ],
        ),
      ),
    );
  }
}
class HeaderComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF9EF84A),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.arrow_back,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

        ],
      ),
    );
  }
}

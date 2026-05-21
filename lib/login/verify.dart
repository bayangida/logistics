import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../logistics/home.dart';

class FarmerLoginOTPPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String password;

  const FarmerLoginOTPPage({
    Key? key,
    required this.verificationId,
    required this.phoneNumber,
    required this.password,
  }) : super(key: key);

  @override
  _FarmerLoginOTPPageState createState() => _FarmerLoginOTPPageState();
}

class _FarmerLoginOTPPageState extends State<FarmerLoginOTPPage> {
  final List<TextEditingController> _codeControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _resendCountdown = 60;
  late Timer _resendTimer;
  String? _currentVerificationId; // Store the verification ID in state

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId; // Initialize with the widget's verificationId
    _startResendCountdown();
    _setupCodeListeners();
  }

  void _setupCodeListeners() {
    for (int i = 0; i < _codeControllers.length; i++) {
      _codeControllers[i].addListener(() {
        if (_codeControllers[i].text.length == 1 && i < _codeControllers.length - 1) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  void _startResendCountdown() {
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    final otp = _codeControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter complete OTP code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!, // Use the current verification ID
        smsCode: otp,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      await _checkUserType(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkUserType(User user) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!doc.exists || doc.data()?['userType'] != 'driver') {
      await FirebaseAuth.instance.signOut();
      throw Exception('You are not registered as a driver');
    }

    // Navigate to farmer dashboard
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomeDashboardPage()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _resendCountdown = 60;
      _isLoading = true;
    });
    _startResendCountdown();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+234${widget.phoneNumber}',
        verificationCompleted: (credential) async {
          await _verifyOTP();
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resend OTP: ${e.message}')),
          );
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _currentVerificationId = verificationId; // Update the verification ID in state
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP resent successfully')),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {},
        timeout: Duration(seconds: 60),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resending OTP: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _resendTimer.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 54),
            HeaderComponent(
              onBack: () => Navigator.pop(context),
            ),
            SizedBox(height: 20),
            Text(
              'Verify Account',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk Variable',
                fontWeight: FontWeight.w800,
                fontSize: 36,
                color: Color(0xFF0B7F40),
                height: 46 / 36,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Code sent to +234 ${widget.phoneNumber}',
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
            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 45,
                  height: 50,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _codeControllers[index].text.isNotEmpty
                          ? Color(0xFF9EF84A)
                          : Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _codeControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 24),
            GestureDetector(
              onTap: _resendCountdown == 0 ? _resendOTP : null,
              child: Text(
                _resendCountdown == 0
                    ? "Didn't receive code? Resend Code"
                    : "Resend code in $_resendCountdown seconds",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _resendCountdown == 0 ? Color(0xFF0B7F40) : Color(0xFF475569),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0B7F40),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Verify Account',
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
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
class HeaderComponent extends StatelessWidget {
  final VoidCallback onBack;

  const HeaderComponent({Key? key, required this.onBack}) : super(key: key);

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
                onTap: onBack,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child:Icon(
                    Icons.arrow_back,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

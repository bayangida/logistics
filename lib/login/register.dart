import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../logistics/home.dart';
import '../providers/user_provider.dart';
import 'driververify.dart';

class RegisterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          // Fixed header section that doesn't scroll
          Container(
            padding: EdgeInsets.only(
              top: screenHeight * 0.05,
              bottom: screenHeight * 0.02,
            ),
            child: Column(
              children: [
                HeaderComponent(title: 'Register'),
                RegisterTitleComponent(),
              ],
            ),
          ),

          // Scrollable form content
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: screenWidth,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                child: FarmerFormComponent(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FarmerFormComponent extends StatefulWidget {
  @override
  _FarmerFormComponentState createState() => _FarmerFormComponentState();
}

class _FarmerFormComponentState extends State<FarmerFormComponent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  // Add this method to calculate password strength
  void _checkPasswordStrength(String password) {
    // Reset strength
    double strength = 0.0;
    String text = '';
    Color color = Colors.grey;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    // Check for length
    if (password.length >= 8) strength += 0.2;

    // Check for uppercase letters
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;

    // Check for lowercase letters
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;

    // Check for numbers
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;

    // Check for special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    // Set strength text and color
    if (strength < 0.4) {
      text = 'Weak';
      color = Colors.red;
    } else if (strength < 0.8) {
      text = 'Medium';
      color = Colors.orange;
    } else {
      text = 'Strong';
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
    });
  }

  // Update the password validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+234${_phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _verifyPhoneNumber(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isLoading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverVerifyOTPPage(
                verificationId: verificationId,
                phoneNumber: _phoneController.text.trim(),
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                password: _passwordController.text.trim(),
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _verifyPhoneNumber(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _completeFarmerRegistration(userCredential.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _completeFarmerRegistration(User user) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Create driver document with user type
      final driverData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'userType': 'driver',
        'accountType': 'individual',
        'createdAt': FieldValue.serverTimestamp(),
        'verified': true,
        'photoUrl': '',
        'status': 'active',
      };

      // Create user document and initialize other collections
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(user.uid);

      batch.set(userRef, driverData);

      // Initialize earnings subcollection
      final earningsRef = userRef.collection('earnings').doc('current');
      batch.set(earningsRef, {
        'monthly': 0,
        'total': 0,
        'available': 0,
        'active_orders': 0,
        'cancelled_orders': 0,
        'completed_orders': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Initialize empty addresses collection
      final addressesRef = userRef.collection('addresses').doc('default');
      batch.set(addressesRef, {
        'address': '',
        'city': '',
        'state': '',
        'zipCode': '',
        'country': '',
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Initialize notification preferences
      final notificationPrefsRef = userRef.collection('preferences').doc('notifications');
      batch.set(notificationPrefsRef, {
        'push': {
          'order_updates': true,
          'promotions': false,
          'delivery_status': true,
        },
        'email': {
          'order_updates': true,
          'promotions': false,
          'newsletter': false,
        },
        'sms': {
          'order_updates': true,
          'promotions': false,
          'delivery_status': true,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Update user provider with the new user data
      await userProvider.fetchUserDetails();

      // Navigate to driver dashboard and clear back stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomeDashboardPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            width: screenWidth,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        label: 'First Name',
                        placeholder: 'Musa',
                        controller: _firstNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter first name';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: _buildInputField(
                        label: 'Last Name',
                        placeholder: 'Inuwa',
                        controller: _lastNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter last name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.015),
                _buildPhoneField(),
                SizedBox(height: screenHeight * 0.015),
                _buildPasswordField(
                  label: 'Password',
                  isVisible: _isPasswordVisible,
                  onVisibilityChanged: (value) {
                    setState(() => _isPasswordVisible = value);
                  },
                  showHint: true,
                  controller: _passwordController,
                  validator: _validatePassword,
                ),
                SizedBox(height: screenHeight * 0.015),
                _buildPasswordField(
                  label: 'Confirm Password',
                  isVisible: _isConfirmPasswordVisible,
                  onVisibilityChanged: (value) {
                    setState(() => _isConfirmPasswordVisible = value);
                  },
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          _buildRegisterButton(context),
          SizedBox(height: screenHeight * 0.02),
          _buildTermsText(),
          SizedBox(height: screenHeight * 0.04),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: screenHeight * 0.008),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenHeight * 0.015,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
              ),
              child: Text(
                '+234',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length < 10) {
                    return 'Enter valid phone number';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenHeight * 0.015,
                  ),
                  hintText: '8012345678',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    borderSide: BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  errorStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: screenWidth * 0.03,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: screenHeight * 0.008),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.015,
            ),
            hintText: placeholder,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
              borderSide: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            errorStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.03,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required bool isVisible,
    required Function(bool) onVisibilityChanged,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    bool showHint = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: screenHeight * 0.008),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator,
          onChanged: (value) {
            if (label == 'Password') {
              _checkPasswordStrength(value);
            }
          },
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.015,
            ),
            hintText: '*********',
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
              borderSide: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                size: screenWidth * 0.05,
              ),
              onPressed: () => onVisibilityChanged(!isVisible),
            ),
            errorStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.03,
            ),
          ),
        ),
        if (showHint)
          Padding(
            padding: EdgeInsets.only(top: screenHeight * 0.005),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Password requirements
                Text(
                  'Password must contain:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  '• 8+ characters\n• 1 uppercase letter\n• 1 lowercase letter\n• 1 number\n• 1 special character',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                // Password strength indicator
                if (controller.text.isNotEmpty)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _passwordStrength,
                        backgroundColor: Colors.grey[200],
                        color: _passwordStrengthColor,
                        minHeight: screenHeight * 0.005,
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        'Strength: $_passwordStrengthText',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: screenWidth * 0.03,
                          color: _passwordStrengthColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0B7F40),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.025),
          ),
        ),
        child: _isLoading
            ? SizedBox(
          width: screenWidth * 0.05,
          height: screenWidth * 0.05,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          'Create Account',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.033,
            fontWeight: FontWeight.w400,
            color: Color(0xFF475569),
          ),
          children: [
            TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderComponent extends StatelessWidget {
  final String title;

  const HeaderComponent({Key? key, this.title = 'Heading'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      height: screenHeight * 0.08,
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.08,
            height: screenWidth * 0.08,
            decoration: const BoxDecoration(
              color: Color(0xFF9EF84A),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.015),
                  child: Icon(
                    Icons.arrow_back,
                    size: screenWidth * 0.05,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
        ],
      ),
    );
  }
}

class RegisterTitleComponent extends StatelessWidget {
  const RegisterTitleComponent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
      alignment: Alignment.center,
      child: Text(
        'Register',
        style: TextStyle(
          fontFamily: 'Cabinet Grotesk Variable',
          fontWeight: FontWeight.w800,
          fontSize: screenWidth * 0.09,
          color: Color(0xFF0B7F40),
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
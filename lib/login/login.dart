import 'dart:io'; // Add for Platform detection
import 'package:bayangida_logistics/login/verify.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../logistics/home.dart';
import '../providers/user_provider.dart';
import 'forgotpassword.dart';
// Add Sign in with Apple package
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

class FarmerLoginPage extends StatefulWidget {
  @override
  _FarmerLoginPageState createState() => _FarmerLoginPageState();
}

class _FarmerLoginPageState extends State<FarmerLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _verificationId;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+234${_phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithPhoneNumber(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FarmerLoginOTPPage(
                verificationId: verificationId,
                phoneNumber: _phoneController.text.trim(),
                password: _passwordController.text.trim(),
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: Duration(seconds: 60),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _signInWithPhoneNumber(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      await _checkUserTypeAndLogin(userCredential.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    }
  }

  // Add Apple Sign-In method
  Future<void> _handleAppleSignIn(BuildContext context) async {
    try {
      // Trigger the Apple Sign-In flow
      final appleCredential = await apple.SignInWithApple.getAppleIDCredential(
        scopes: [
          apple.AppleIDAuthorizationScopes.email,
          apple.AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) return;

      await _checkUserTypeAndLogin(user);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in with Apple: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkUserTypeAndLogin(User user) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data()?['userType'] != 'driver') {
        await FirebaseAuth.instance.signOut();
        throw Exception('You are not registered as a driver');
      }

      // Update user provider with the new user data
      await userProvider.fetchUserDetails();

      // Navigate to main wrapper and clear back stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomeDashboardPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 54),
              HeaderComponent(title: 'Login'),
              SizedBox(height: 20),
              Text(
                'Login',
                style: TextStyle(
                  fontFamily: 'Cabinet Grotesk Variable',
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  color: Color(0xFF0B7F40),
                  height: 46 / 36,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              FarmerLoginForm(
                phoneController: _phoneController,
                passwordController: _passwordController,
                formKey: _formKey,
                isLoading: _isLoading,
                onLoginPressed: _sendOTP,
                onAppleSignIn: _handleAppleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FarmerLoginForm extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onLoginPressed;
  final Function(BuildContext) onAppleSignIn;

  const FarmerLoginForm({
    Key? key,
    required this.phoneController,
    required this.passwordController,
    required this.formKey,
    required this.isLoading,
    required this.onLoginPressed,
    required this.onAppleSignIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _buildPhoneField(),
          SizedBox(height: 16),
          _buildPasswordField(),
          SizedBox(height: 4),
          _buildForgotpass(context),
          SizedBox(height: 20), // Reduced space
          _buildLoginButton(context),
          SizedBox(height: 16),
          _buildRegisterLink(context),
          SizedBox(height: 16),
          _buildgoogle(context),
          // Add Apple Sign-In button (only show on iOS)
          if (Platform.isIOS) SizedBox(height: 16),
          if (Platform.isIOS) _buildAppleSignIn(context),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+234',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: phoneController,
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: '8012345678',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForgotpass(BuildContext context) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForgotPasswordPage(),
                ),
              );
            },
            child: Text(
              'Forgot password',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF3C9AFB),
              ),
            ),
          ),
        ]);
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter password';
            }
            return null;
          },
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: '********',
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onLoginPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0B7F40),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
          'Login',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "or ",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildgoogle(BuildContext context) {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            final googleSignIn = GoogleSignIn();
            final auth = FirebaseAuth.instance;

            final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
            if (googleUser == null) {
              throw Exception("Google sign-in was cancelled");
            }

            final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
            final AuthCredential credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );

            UserCredential userCredential = await auth.signInWithCredential(credential);
            final User? user = userCredential.user;

            if (user == null) {
              throw Exception("Failed to authenticate user");
            }

            // Check if user exists in Firestore
            final userDoc = await _firestore
                .collection('users')
                .doc(user.uid)
                .get();

            if (!userDoc.exists || userDoc.data()?['userType'] != 'driver') {
              await auth.signOut();
              await googleSignIn.signOut();
              throw Exception("Driver account not found. Please register as a driver first.");
            }

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => WelcomeDashboardPage()),
                  (Route<dynamic> route) => false,
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google sign-in failed: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        },
        icon: Image.asset(
          'assets/images/google_logo.png',
          width: 24,
          height: 24,
        ),
        label: const Text(
          'Login with Google',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.black12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 56),
          elevation: 1,
        ),
      ),
    );
  }

  // Add Apple Sign-In button
  Widget _buildAppleSignIn(BuildContext context) {
    return Container(
      width: double.infinity,
      child: apple.SignInWithAppleButton(
        onPressed: () => onAppleSignIn(context),
        iconAlignment: apple.IconAlignment.center,
        style: apple.SignInWithAppleButtonStyle.black,
        text: 'Sign in with Apple',
        height: 50,
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }
}

class HeaderComponent extends StatelessWidget {
  final String title;

  const HeaderComponent({Key? key, this.title = 'Heading'}) : super(key: key);

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
                onTap: () => Navigator.pop(context),
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
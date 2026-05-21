import 'package:bayangida_logistics/login/regselect.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logistics/home.dart';
import '../providers/user_provider.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// 1. Import the package
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

class Authselect extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final _firestore = FirebaseFirestore.instance;

      // Check if user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Create driver document with all required fields
        final driverData = {
          'uid': user.uid,
          'email': user.email,
          'firstName': googleUser.displayName?.split(' ').first ?? '',
          'lastName': googleUser.displayName?.split(' ').last ?? '',
          'phone': user.phoneNumber ?? '',
          'userType': 'driver',
          'accountType': 'individual',
          'createdAt': FieldValue.serverTimestamp(),
          'verified': true,
          'photoUrl': user.photoURL ?? '',
          'status': 'active',
          'isAvailable': false,
          'vehicleType': '',
          'vehicleNumber': '',
          'licenseNumber': '',
        };

        // Create user document and initialize other collections using batch
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
        final fleetRef = userRef.collection('fleet').doc('default');
        batch.set(fleetRef, {
          'address': '',
          'city': '',
          'state': '',
          'zipCode': '',
          'country': '',
          'license': '',
          'vehicleType': '',
          'name': '',
          'colour': '',
          'model': '',
          'plateNumber': '',
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
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
      }

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
        SnackBar(content: Text('Failed to sign in: ${e.toString()}')),
      );
    }
  }


  // 2. Create a new method for Apple Sign-In
  Future<void> _handleAppleSignIn(BuildContext context) async {
    try {
      // 3. Trigger the Apple Sign-In flow
      final appleCredential = await apple.SignInWithApple.getAppleIDCredential(
        scopes: [
          apple.AppleIDAuthorizationScopes.email,
          apple.AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 4. Create an OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 5. Sign in to Firebase with the Apple credential
      UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final _firestore = FirebaseFirestore.instance;

      // 6. Check if user exists in Firestore (same logic as Google)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Apple might not return the full name on subsequent logins.
        // It's only guaranteed on the first sign-in. We use what we have.
        String? firstName = appleCredential.givenName;
        String? lastName = appleCredential.familyName;

        // If name is null (e.g., on subsequent logins), check Firebase User
        // which might have the display name from the first sign-in.
        if ((firstName == null || lastName == null) && user.displayName != null) {
          var nameParts = user.displayName!.split(' ');
          firstName = nameParts.first;
          lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        }

        final driverData = {
          'uid': user.uid,
          'email': user.email, // Apple provides a real or private relay email
          'firstName': firstName ?? '',
          'lastName': lastName ?? '',
          'phone': user.phoneNumber ?? '',
          'userType': 'driver',
          'accountType': 'individual',
          'createdAt': FieldValue.serverTimestamp(),
          'verified': true,
          'photoUrl': user.photoURL ?? '', // Apple does not provide a photo URL
          'status': 'active',
          'isAvailable': false,
          'vehicleType': '',
          'vehicleNumber': '',
          'licenseNumber': '',
        };

        // ... your existing batch write code for new users remains the same ...
        final batch = _firestore.batch();
        final userRef = _firestore.collection('users').doc(user.uid);

        batch.set(userRef, driverData);

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

        final fleetRef = userRef.collection('fleet').doc('default');
        batch.set(fleetRef, {
          'address': '',
          'city': '',
          'state': '',
          'zipCode': '',
          'country': '',
          'license': '',
          'vehicleType': '',
          'name': '',
          'colour': '',
          'model': '',
          'plateNumber': '',
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

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
      }

      // 7. Update user provider and navigate
      await userProvider.fetchUserDetails();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomeDashboardPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in with Apple: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              "assets/images/auth.jpeg",
              fit: BoxFit.cover,
            ),
          ),

          // Semi-transparent dark green overlay
          Positioned.fill(
            child: Container(
              color: const Color(0xFF042E22).withOpacity(0.85),
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with 50px bottom margin
                  Container(
                    margin: const EdgeInsets.only(bottom: 50),
                    child: Image.asset(
                      'assets/images/logoonly.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Buttons container with blur effect
                  SizedBox(height: 180,),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color:const Color(0xFF042E22).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF042E22).withOpacity(0.40),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Register and Login buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => Regselect()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 06),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => FarmerLoginPage()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google login button
                        ElevatedButton.icon(
                          onPressed: () => _handleGoogleSignIn(context),
                          icon: Image.asset(
                            'assets/images/google_logo.png',
                            width: 24,
                            height: 24,
                          ),
                          label: Container(
                            width: 220,
                            child: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 60),
                            elevation: 1,
                          ),
                        ),

                        // 8. Add Apple Sign-In Button
                        const SizedBox(height: 16), // Add some spacing
                        apple.SignInWithAppleButton(
                          onPressed: () => _handleAppleSignIn(context),
                          iconAlignment: apple.IconAlignment.center,
                          style: apple.SignInWithAppleButtonStyle.white, // Or use 'black'
                          text: 'Continue with Apple',
                          height: 50, // Match your other buttons
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
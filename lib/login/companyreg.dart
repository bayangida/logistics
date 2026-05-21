import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../logistics/home.dart';
import '../providers/user_provider.dart';
import 'driververify.dart';

class CompanyRegisterPage extends StatelessWidget {
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
                HeaderComponent(title: 'Company Register'),
                RegisterTitleComponent(title: 'Company Registration'),
              ],
            ),
          ),

          // Scrollable form content
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: screenWidth,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                child: CompanyFormComponent(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyFormComponent extends StatefulWidget {
  @override
  _CompanyFormComponentState createState() => _CompanyFormComponentState();
}

class _CompanyFormComponentState extends State<CompanyFormComponent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // State variables
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;

  // Dropdown values
  String? _selectedState;
  String? _selectedCity;

  // Sample data
  final Map<String, List<String>> _nigeriaStatesWithCities = {
    'Lagos': ['Lagos Island', 'Lagos Mainland', 'Ikeja', 'Victoria Island', 'Lekki'],
    'Abuja': ['Garki', 'Wuse', 'Maitama', 'Asokoro', 'Lugbe'],
    'Kano': ['Kano Municipal', 'Nassarawa', 'Fagge', 'Dala', 'Gwale'],
    'Rivers': ['Port Harcourt', 'Obio-Akpor', 'Eleme', 'Okrika', 'Oyigbo'],
    'Oyo': ['Ibadan', 'Ogbomosho', 'Oyo', 'Iseyin', 'Saki'],
  };

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
        phoneNumber: '+234${_contactPhoneController.text.trim()}',
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
                phoneNumber: _contactPhoneController.text.trim(),
                firstName: _contactPersonController.text.trim(),
                lastName: '', // Not used for company
                password: _passwordController.text.trim(),
                isCompany: true,
                companyData: {
                  'companyName': _companyNameController.text.trim(),
                  'address': _addressController.text.trim(),
                  'contactPerson': _contactPersonController.text.trim(),
                  'contactEmail': _contactEmailController.text.trim(),
                  'contactPhone': _contactPhoneController.text.trim(),
                  'registrationNumber': _regNumberController.text.trim(),
                  'state': _selectedState,
                  'city': _selectedCity,
                  'accountType': 'company',
                  'status': 'pending',
                },
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
      await _completeCompanyRegistration(userCredential.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _completeCompanyRegistration(User user) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Create company document
      final companyData = {
        'companyName': _companyNameController.text.trim(),
        'address': _addressController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactEmail': _contactEmailController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'registrationNumber': _regNumberController.text.trim(),
        'state': _selectedState,
        'city': _selectedCity,
        'createdAt': FieldValue.serverTimestamp(),
        'accountType': 'company',
        'status': 'pending',
        'verified': true,
        'photoUrl': '',
        'userType': 'driver',
      };

      // Create user document and initialize other collections
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(user.uid);

      batch.set(userRef, companyData);

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

      // Navigate to dashboard and clear back stack
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
    _companyNameController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _regNumberController.dispose();
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
          _buildInputField(
            label: 'Company Name',
            placeholder: 'Enter your company name',
            controller: _companyNameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter company name';
              }
              return null;
            },
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildInputField(
            label: 'Company Address',
            placeholder: 'Enter your company address',
            controller: _addressController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter company address';
              }
              return null;
            },
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildInputField(
            label: 'Contact Person Name',
            placeholder: 'Enter contact person name',
            controller: _contactPersonController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter contact person name';
              }
              return null;
            },
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildInputField(
            label: 'Contact Email',
            placeholder: 'Enter contact email',
            controller: _contactEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter valid email';
              }
              return null;
            },
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildPhoneField(),
          SizedBox(height: screenHeight * 0.015),
          _buildInputField(
            label: 'Company Registration Number',
            placeholder: 'Enter registration number',
            controller: _regNumberController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter registration number';
              }
              return null;
            },
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildPasswordField(
            label: 'Password',
            isVisible: _isPasswordVisible,
            onVisibilityChanged: (value) {
              setState(() => _isPasswordVisible = value);
            },
            showHint: true,
            controller: _passwordController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
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
          SizedBox(height: screenHeight * 0.02),
          Text(
            'Service Area',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildDropdownField(
            hint: 'Select state',
            value: _selectedState,
            items: _nigeriaStatesWithCities.keys.toList(),
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _selectedCity = null;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select state';
              }
              return null;
            },
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildDropdownField(
            hint: _selectedState == null ? 'Select state first' : 'Select city',
            value: _selectedCity,
            items: _selectedState != null
                ? _nigeriaStatesWithCities[_selectedState]!
                : [],
            onChanged: _selectedState != null
                ? (String? value) {
              setState(() {
                _selectedCity = value;
              });
            }
                : null,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select city';
              }
              return null;
            },
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
          'Contact Phone Number',
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
                controller: _contactPhoneController,
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
                color: Colors.grey,
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
            child: Text(
              'Must be at least 8 characters',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: screenWidth * 0.03,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    required String? Function(String?)? validator,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.035,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.015,
        ),
        hintText: hint,
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
        suffixIcon: Icon(
          Icons.arrow_drop_down,
          size: screenWidth * 0.05,
        ),
        errorStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: screenWidth * 0.03,
        ),
      ),
      icon: SizedBox.shrink(),
      isExpanded: true,
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
          'Register Company',
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

// Reusable components
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
  final String title;

  const RegisterTitleComponent({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
      alignment: Alignment.center,
      child: Text(
        title,
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
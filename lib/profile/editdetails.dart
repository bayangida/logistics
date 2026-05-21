import 'package:bayangida_logistics/logistics/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:async';

import '../logistics/notificationstatus.dart';
import '../providers/user_provider.dart';

class personaledit extends StatefulWidget {
  @override
  _personaleditState createState() => _personaleditState();
}

class _personaleditState extends State<personaledit> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  File? _profileImage;
  bool _isLoading = false;
  String? _profileImageUrl;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _nameController.text = data['firstName'] ?? user.displayName ?? 'User';
          _emailController.text = data['email'] ?? user.email ?? 'No email';
          _phoneController.text = data['phone'] ?? '';
          _profileImageUrl = data['photoUrl'];

          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.displayName = _nameController.text;
          userProvider.profilePictureUrl = _profileImageUrl;
          userProvider.phoneNumber = _phoneController.text;
          userProvider.notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToSupabase(File imageFile) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final fileExtension = imageFile.path.split('.').last;
      final fileName = 'profile_$userId.$fileExtension';
      final filePath = 'profile_pictures/$fileName';

      await _supabase.storage
          .from('userprofileimages')
          .upload(filePath, imageFile);

      final imageUrl = _supabase.storage
          .from('userprofileimages')
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      print('Error uploading image to Supabase: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = user?.uid;
      final newEmail = _emailController.text.trim();
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();

      if (userId == null) throw Exception('User not authenticated');

      String? newImageUrl = _profileImageUrl;
      if (_profileImage != null) {
        newImageUrl = await _uploadImageToSupabase(_profileImage!);
      }

      final userData = {
        'firstName': newName,
        'email': newEmail,
        'phone': newPhone,
        if (newImageUrl != null) 'photoUrl': newImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));

      if (newName != user?.displayName) {
        await user?.updateDisplayName(newName);
      }

      if (newEmail != user?.email) {
        try {
          await user?.verifyBeforeUpdateEmail(newEmail);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification email sent to $newEmail. Please verify your new email address.'),
              duration: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          print('Error updating email: $e');
        }
      }

      userProvider.displayName = newName;
      userProvider.phoneNumber = newPhone;
      if (newImageUrl != null) {
        userProvider.profilePictureUrl = newImageUrl;
      }
      userProvider.notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                ? _buildPersonalInfoForm()
                : LogisticsBankAccountSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Personal Info',
              isActive: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _TabButton(
              title: 'Bank Account',
              isActive: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          SizedBox(height: 20),
          GestureDetector(
            onTap: _pickImage,
            child: ProfilePicture(
              imageUrl: _profileImage != null ? null : _profileImageUrl,
              localImage: _profileImage,
            ),
          ),
          SizedBox(height: 20),
          _ProfileInputField(
            label: 'Name',
            controller: _nameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          _ProfileInputField(
            label: 'Email',
            controller: _emailController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          _PhoneInputField(
            label: 'Phone Number',
            controller: _phoneController,
          ),
          SizedBox(height: 32),
          _SaveChangesButton(
            onPressed: _isLoading ? null : _updateProfile,
            isLoading: _isLoading,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class LogisticsBankAccountSection extends StatefulWidget {
  @override
  _LogisticsBankAccountSectionState createState() => _LogisticsBankAccountSectionState();
}

class _LogisticsBankAccountSectionState extends State<LogisticsBankAccountSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _bankDetails;
  bool _isLoading = true;
  bool _showAddForm = false;
  bool _showPasswordForm = false;
  bool _isEditing = false;

  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _bankPasswordController = TextEditingController();
  final TextEditingController _confirmBankPasswordController = TextEditingController();

  // Nigerian banks list
  final List<String> _nigerianBanks = [
    'Access Bank',
    'Citibank Nigeria',
    'Ecobank Nigeria',
    'Fidelity Bank',
    'First Bank of Nigeria',
    'First City Monument Bank',
    'Globus Bank',
    'Guaranty Trust Bank',
    'Heritage Bank',
    'Jaiz Bank',
    'Keystone Bank',
    'Polaris Bank',
    'Providus Bank',
    'Stanbic IBTC Bank',
    'Standard Chartered Bank',
    'Sterling Bank',
    'Suntrust Bank',
    'Union Bank of Nigeria',
    'United Bank for Africa',
    'Unity Bank',
    'Wema Bank',
    'Zenith Bank'
  ];

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _bankDetails = data['bankDetails'];
          });
        }
      }
    } catch (e) {
      print('Error loading bank details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startBankAccountProcess({bool isEditing = false}) {
    _isEditing = isEditing;

    if (isEditing && _bankDetails != null) {
      _bankNameController.text = _bankDetails?['bankName'] ?? '';
      _accountNumberController.text = _bankDetails?['accountNumber'] ?? '';
      _accountNameController.text = _bankDetails?['accountName'] ?? '';
    } else {
      _bankNameController.clear();
      _accountNumberController.clear();
      _accountNameController.clear();
    }

    setState(() {
      _showAddForm = true;
      _showPasswordForm = false;
    });
  }

  void _proceedToPasswordSetup() {
    if (_bankNameController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        _accountNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all bank details')),
      );
      return;
    }

    setState(() {
      _showAddForm = false;
      _showPasswordForm = true;
    });
  }

  Future<void> _verifyBankPasswordAndSendOTP() async {
    if (_bankPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter bank account password')),
      );
      return;
    }

    if (!_isEditing && _bankPasswordController.text != _confirmBankPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // For editing, verify the existing bank password
      if (_isEditing && _bankDetails != null) {
        final storedPassword = _bankDetails?['bankPassword'];
        if (storedPassword != _bankPasswordController.text) {
          throw Exception('Invalid bank account password');
        }
      }

      // Get user's phone number for OTP
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final phoneNumber = userDoc.data()?['phone'];

      if (phoneNumber == null) {
        throw Exception('Phone number not found');
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: '+234$phoneNumber',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _processBankAccountUpdate(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogisticsBankAccountOTPVerificationPage(
                verificationId: verificationId,
                bankName: _bankNameController.text,
                accountNumber: _accountNumberController.text,
                accountName: _accountNameController.text,
                bankPassword: _bankPasswordController.text,
                isEditing: _isEditing,
              ),
            ),
          ).then((_) {
            _resetForms();
            _loadBankDetails();
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: Duration(seconds: 60),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processBankAccountUpdate(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update bank details in Firestore
      final bankDetails = {
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'bankPassword': _bankPasswordController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'verified': true,
      };

      await _firestore.collection('users').doc(user.uid).set({
        'bankDetails': bankDetails
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bank account details ${_isEditing ? 'updated' : 'added'} successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bank details: ${e.toString()}')),
      );
    }
  }

  void _resetForms() {
    _bankNameController.clear();
    _accountNumberController.clear();
    _accountNameController.clear();
    _bankPasswordController.clear();
    _confirmBankPasswordController.clear();
    setState(() {
      _showAddForm = false;
      _showPasswordForm = false;
      _isEditing = false;
    });
  }

  Future<void> _changeBankPassword() async {
    showDialog(
      context: context,
      builder: (context) => LogisticsChangeBankPasswordDialog(),
    ).then((_) {
      _loadBankDetails();
    });
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _bankPasswordController.dispose();
    _confirmBankPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_bankDetails != null) _buildCurrentBankDetails(),
          if (!_showAddForm && !_showPasswordForm && _bankDetails == null)
            _buildAddBankButton(),
          if (_showAddForm) _buildBankDetailsForm(),
          if (_showPasswordForm) _buildBankPasswordForm(),
        ],
      ),
    );
  }

  Widget _buildCurrentBankDetails() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bank Account Details',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0B7F40),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _startBankAccountProcess(isEditing: true);
                    } else if (value == 'change_password') {
                      _changeBankPassword();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit Account')),
                    PopupMenuItem(value: 'change_password', child: Text('Change Password')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            _BankDetailRow(
              label: 'Bank Name',
              value: _bankDetails?['bankName'] ?? 'Not set',
            ),
            _BankDetailRow(
              label: 'Account Number',
              value: _bankDetails?['accountNumber'] ?? 'Not set',
            ),
            _BankDetailRow(
              label: 'Account Name',
              value: _bankDetails?['accountName'] ?? 'Not set',
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBankButton() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Bank Account Added',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _startBankAccountProcess(isEditing: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0B7F40),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Add Bank Account',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Bank Account' : 'Add Bank Account',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B7F40),
              ),
            ),
            SizedBox(height: 16),
            _BankDropdownField(
              label: 'Bank Name',
              controller: _bankNameController,
              banks: _nigerianBanks,
            ),
            SizedBox(height: 12),
            _BankInputField(
              label: 'Account Number',
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter account number';
                }
                if (value.length != 10) {
                  return 'Account number must be 10 digits';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            _BankInputField(
              label: 'Account Name',
              controller: _accountNameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter account name';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetForms,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFF0B7F40)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Color(0xFF0B7F40),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _proceedToPasswordSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0B7F40),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankPasswordForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Verify Bank Password' : 'Set Bank Account Password',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B7F40),
              ),
            ),
            SizedBox(height: 8),
            Text(
              _isEditing
                  ? 'Enter your bank account password and verify with OTP to update your account details.'
                  : 'Set a secure password for your bank account. You will need this password along with OTP verification for any future changes.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            _BankInputField(
              label: 'Bank Account Password',
              controller: _bankPasswordController,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            if (!_isEditing) SizedBox(height: 12),
            if (!_isEditing)
              _BankInputField(
                label: 'Confirm Password',
                controller: _confirmBankPasswordController,
                obscureText: true,
                validator: (value) {
                  if (value != _bankPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _showPasswordForm = false;
                      _showAddForm = true;
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFF0B7F40)),
                    ),
                    child: Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Color(0xFF0B7F40),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyBankPasswordAndSendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0B7F40),
                      padding: EdgeInsets.symmetric(vertical: 12),
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
                      _isEditing ? 'Verify & Send OTP' : 'Set Password & Send OTP',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LogisticsChangeBankPasswordDialog extends StatefulWidget {
  @override
  _LogisticsChangeBankPasswordDialogState createState() => _LogisticsChangeBankPasswordDialogState();
}

class _LogisticsChangeBankPasswordDialogState extends State<LogisticsChangeBankPasswordDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _bankDetails;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _bankDetails = doc.data()?['bankDetails'];
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmNewPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }

    // Verify current password
    if (_bankDetails?['bankPassword'] != _currentPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Current password is incorrect')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's phone number for OTP
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final phoneNumber = userDoc.data()?['phone'];

      if (phoneNumber == null) {
        throw Exception('Phone number not found');
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: '+234$phoneNumber',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _updateBankPassword(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogisticsChangeBankPasswordOTPPage(
                verificationId: verificationId,
                newPassword: _newPasswordController.text,
              ),
            ),
          ).then((_) {
            Navigator.pop(context); // Close dialog
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: Duration(seconds: 60),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBankPassword(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update bank password in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'bankDetails.bankPassword': _newPasswordController.text.trim(),
        'bankDetails.lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bank account password updated successfully')),
      );

      Navigator.pop(context); // Close OTP page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Bank Account Password',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B7F40),
              ),
            ),
            SizedBox(height: 16),
            _BankInputField(
              label: 'Current Password',
              controller: _currentPasswordController,
              obscureText: true,
            ),
            SizedBox(height: 12),
            _BankInputField(
              label: 'New Password',
              controller: _newPasswordController,
              obscureText: true,
            ),
            SizedBox(height: 12),
            _BankInputField(
              label: 'Confirm New Password',
              controller: _confirmNewPasswordController,
              obscureText: true,
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFF0B7F40)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Color(0xFF0B7F40),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0B7F40),
                      padding: EdgeInsets.symmetric(vertical: 12),
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
                      'Change Password',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LogisticsBankAccountOTPVerificationPage extends StatefulWidget {
  final String verificationId;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String bankPassword;
  final bool isEditing;

  const LogisticsBankAccountOTPVerificationPage({
    Key? key,
    required this.verificationId,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.bankPassword,
    required this.isEditing,
  }) : super(key: key);

  @override
  _LogisticsBankAccountOTPVerificationPageState createState() => _LogisticsBankAccountOTPVerificationPageState();
}

class _LogisticsBankAccountOTPVerificationPageState extends State<LogisticsBankAccountOTPVerificationPage> {
  final List<TextEditingController> _codeControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _resendCountdown = 60;
  late Timer _resendTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
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
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      await _updateBankDetails(credential);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _resendCountdown = 60;
      _isLoading = true;
    });
    _startResendCountdown();

    try {
      final user = _auth.currentUser;
      final userDoc = await _firestore.collection('users').doc(user!.uid).get();
      final phoneNumber = userDoc.data()?['phone'];

      await _auth.verifyPhoneNumber(
        phoneNumber: '+234$phoneNumber',
        verificationCompleted: (credential) async {
          await _updateBankDetails(credential);
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resend OTP: ${e.message}')),
          );
        },
        codeSent: (verificationId, resendToken) {
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

  Future<void> _updateBankDetails(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update bank details in Firestore
      final bankDetails = {
        'bankName': widget.bankName,
        'accountNumber': widget.accountNumber,
        'accountName': widget.accountName,
        'bankPassword': widget.bankPassword,
        'lastUpdated': FieldValue.serverTimestamp(),
        'verified': true,
      };

      await _firestore.collection('users').doc(user.uid).set({
        'bankDetails': bankDetails
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bank account details ${widget.isEditing ? 'updated' : 'added'} successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bank details: ${e.toString()}')),
      );
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
      appBar: AppBar(
        title: Text('Verify OTP'),
        backgroundColor: Color(0xFF0B7F40),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify Phone Number',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk Variable',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Color(0xFF0B7F40),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to your phone number to ${widget.isEditing ? 'update' : 'add'} your bank account.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
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
                  padding: EdgeInsets.symmetric(vertical: 12),
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
                  'Verify & ${widget.isEditing ? 'Update' : 'Add'} Bank Account',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogisticsChangeBankPasswordOTPPage extends StatefulWidget {
  final String verificationId;
  final String newPassword;

  const LogisticsChangeBankPasswordOTPPage({
    Key? key,
    required this.verificationId,
    required this.newPassword,
  }) : super(key: key);

  @override
  _LogisticsChangeBankPasswordOTPPageState createState() => _LogisticsChangeBankPasswordOTPPageState();
}

class _LogisticsChangeBankPasswordOTPPageState extends State<LogisticsChangeBankPasswordOTPPage> {
  final List<TextEditingController> _codeControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _resendCountdown = 60;
  late Timer _resendTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
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
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      await _updateBankPassword(credential);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _resendCountdown = 60;
      _isLoading = true;
    });
    _startResendCountdown();

    try {
      final user = _auth.currentUser;
      final userDoc = await _firestore.collection('users').doc(user!.uid).get();
      final phoneNumber = userDoc.data()?['phone'];

      await _auth.verifyPhoneNumber(
        phoneNumber: '+234$phoneNumber',
        verificationCompleted: (credential) async {
          await _updateBankPassword(credential);
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resend OTP: ${e.message}')),
          );
        },
        codeSent: (verificationId, resendToken) {
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

  Future<void> _updateBankPassword(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update bank password in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'bankDetails.bankPassword': widget.newPassword.trim(),
        'bankDetails.lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bank account password updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: ${e.toString()}')),
      );
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
      appBar: AppBar(
        title: Text('Verify OTP'),
        backgroundColor: Color(0xFF0B7F40),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify Phone Number',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk Variable',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Color(0xFF0B7F40),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to your phone number to change your bank account password.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
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
                  padding: EdgeInsets.symmetric(vertical: 12),
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
                  'Verify & Change Password',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets
class _TabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFF0B7F40) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Color(0xFF0B7F40) : Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Color(0xFF0B7F40),
          ),
        ),
      ),
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _BankDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankDropdownField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> banks;

  const _BankDropdownField({
    required this.label,
    required this.controller,
    required this.banks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: controller.text.isEmpty ? null : controller.text,
            items: banks.map((String bank) {
              return DropdownMenuItem<String>(
                value: bank,
                child: Text(
                  bank,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              controller.text = newValue ?? '';
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a bank';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _BankInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _BankInputField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// Your Original Components (Keep them as they are)
class _ProfileInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final String? Function(String?)? validator;

  const _ProfileInputField({
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: TextFormField(
              controller: controller,
              readOnly: readOnly,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1E293B),
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _PhoneInputField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 8),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                      hintText: '8012345678',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1E293B),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaveChangesButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SaveChangesButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0B7F40),
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : Text(
            'Save Changes',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF042E22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back button aligned to the left
          Padding(
            padding: const EdgeInsets.only(top: 60.0,bottom: 28),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0B7F40),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF9EF84A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Centered title
          Padding(
            padding: const EdgeInsets.only(top: 60.0,bottom: 28),
            child: Center(
              child: Text(
                'Edit details',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Notification icon aligned to the right
          Padding(
            padding: const EdgeInsets.only(top: 60.0,bottom: 28,right :9),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotificationsPage()),
                  );
                },
                child: Icon(
                  Icons.notifications,
                  color: Color(0xFF9EF84A),
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePicture extends StatelessWidget {
  final String? imageUrl;
  final File? localImage;

  const ProfilePicture({this.imageUrl, this.localImage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: localImage != null
                ? FileImage(localImage!) as ImageProvider
                : (imageUrl != null
                ? NetworkImage(imageUrl!)
                : AssetImage('assets/default_profile.png') as ImageProvider),
            child: (localImage == null && imageUrl == null)
                ? Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFF9EF84A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit,
                color: Color(0xFF0B7F40),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BottomNavigationBarComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF0B3D3A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          BottomNavItem(icon: Icons.home, label: 'Home'),
          BottomNavItem(icon: Icons.store, label: 'Market'),
          BottomNavItem(icon: Icons.shopping_cart, label: 'Orders'),
          BottomNavItem(icon: Icons.person, label: 'Profile', isActive: true),
        ],
      ),
    );
  }
}

class BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const BottomNavItem({required this.icon, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? Color(0xFF9EF84A) : Color(0xFF0B7F40),
          size: 24,
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isActive ? Color(0xFF9EF84A) : Color(0xFF0B7F40),
          ),
        ),
      ],
    );
  }
}
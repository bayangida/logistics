import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  String? _displayName;
  String? _uid;
  String? _profilePictureUrl;
  String? _userType;
  bool _isLoading = false;
  String? _error;
  String? _email;
  String? _phoneNumber; // Added phone number
  Map<String, dynamic>? _earnings;
  List<Map<String, dynamic>> _addresses = [];
  StreamSubscription<User?>? _authSubscription;

  User? get user => _user;
  String? get displayName => _displayName;
  String? get uid => _uid;
  String? get profilePictureUrl => _profilePictureUrl;
  String? get userType => _userType;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get email => _email;
  String? get phoneNumber => _phoneNumber; // Added getter
  Map<String, dynamic>? get earnings => _earnings;
  List<Map<String, dynamic>> get addresses => _addresses;

  set displayName(String? value) {
    _displayName = value;
    notifyListeners();
  }

  set profilePictureUrl(String? value) {
    _profilePictureUrl = value;
    notifyListeners();
  }

  set phoneNumber(String? value) {
    _phoneNumber = value;
    notifyListeners();
  }

  UserProvider() {
    _initUser();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && _user != null) {
        clearUser(); // User signed out
      } else if (user != null && _user == null) {
        setUser(user); // User signed in
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      _user = FirebaseAuth.instance.currentUser;
      _uid = _user?.uid;

      if (_uid != null) {
        await fetchUserDetails();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('UserProvider initialization error: $e');
      }
    }
  }

  void setUser(User? user) {
    _user = user;
    _uid = user?.uid;
    notifyListeners();

    if (user != null) {
      fetchUserDetails();
    }
  }

  Future<void> fetchUserDetails() async {
    if (_uid == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (doc.exists) {
        _displayName = doc.data()?['firstName'] ?? 'User';
        _profilePictureUrl = doc.data()?['photoUrl'];
        _userType = doc.data()?['userType'];
        _email = doc.data()?['email'];
        _phoneNumber = doc.data()?['phone']; // Fetch phone number
      } else {
        _displayName = 'User';
        _userType = null;
        _email = null;
        _phoneNumber = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Error fetching user details: $e');
      }
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await FirebaseAuth.instance.signOut();
      clearUser();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Map<String, dynamic> _getDefaultEarnings() {
    return {
      'monthly': 0,
      'total': 0,
      'available': 0,
      'active_orders': 0,
      'cancelled_orders': 0,
      'completed_orders': 0,
    };
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      if (_uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update(updates);

      // Update local state
      if (updates.containsKey('firstName')) {
        _displayName = updates['firstName'];
      }
      if (updates.containsKey('photoUrl')) {
        _profilePictureUrl = updates['photoUrl'];
      }
      if (updates.containsKey('phone')) {
        _phoneNumber = updates['phone'];
      }
      if (updates.containsKey('email')) {
        _email = updates['email'];
      }

      notifyListeners();
    } catch (e) {
      throw e;
    }
  }

  Future<void> updateAddress(String addressId, Map<String, dynamic> updates) async {
    try {
      if (_uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('addresses')
          .doc(addressId)
          .update(updates);

      await fetchUserDetails();
    } catch (e) {
      throw e;
    }
  }

  Future<void> addAddress(Map<String, dynamic> addressData) async {
    try {
      if (_uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('addresses')
          .add({
        ...addressData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await fetchUserDetails();
    } catch (e) {
      throw e;
    }
  }

  void clearUser() {
    _user = null;
    _displayName = null;
    _uid = null;
    _profilePictureUrl = null;
    _email = null;
    _phoneNumber = null; // Clear phone number
    _error = null;
    notifyListeners();
  }
}
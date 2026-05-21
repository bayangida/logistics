import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../logistics/notificationstatus.dart';

class NotificationPreferencesPage extends StatefulWidget {
  @override
  _NotificationPreferencesPageState createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic> _notificationPrefs = {
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
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('preferences')
          .doc('notifications')
          .get();

      if (doc.exists) {
        setState(() {
          _notificationPrefs = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        await _initializeDefaultPreferences();
        await _loadNotificationPreferences();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load preferences: ${e.toString()}')),
      );
    }
  }
  Future<void> _initializeDefaultPreferences() async {
    if (_user == null) return;

    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('preferences')
        .doc('notifications')
        .set({
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
  }

  Future<void> _savePreferences() async {
    if (_user == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('preferences')
          .doc('notifications')
          .update({
        ..._notificationPrefs,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preferences saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preferences: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updatePreference(String category, String key, bool value) {
    setState(() {
      _notificationPrefs[category][key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Space for the status bar
          HeaderComponent(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView(
              padding: EdgeInsets.all(16),
              children: [
                NotificationCategory(
                  title: 'Push Notifications',
                  options: [
                    NotificationOption(
                      label: 'Order Updates',
                      value: _notificationPrefs['push']['order_updates'] ?? true,
                      onChanged: (value) => _updatePreference('push', 'order_updates', value),
                    ),
                    NotificationOption(
                      label: 'Promotions',
                      value: _notificationPrefs['push']['promotions'] ?? false,
                      onChanged: (value) => _updatePreference('push', 'promotions', value),
                    ),
                    NotificationOption(
                      label: 'Delivery Status',
                      value: _notificationPrefs['push']['delivery_status'] ?? true,
                      onChanged: (value) => _updatePreference('push', 'delivery_status', value),
                    ),
                  ],
                ),
                NotificationCategory(
                  title: 'Email Notifications',
                  options: [
                    NotificationOption(
                      label: 'Order Updates',
                      value: _notificationPrefs['email']['order_updates'] ?? true,
                      onChanged: (value) => _updatePreference('email', 'order_updates', value),
                    ),
                    NotificationOption(
                      label: 'Promotions',
                      value: _notificationPrefs['email']['promotions'] ?? false,
                      onChanged: (value) => _updatePreference('email', 'promotions', value),
                    ),
                    NotificationOption(
                      label: 'Newsletter',
                      value: _notificationPrefs['email']['newsletter'] ?? false,
                      onChanged: (value) => _updatePreference('email', 'newsletter', value),
                    ),
                  ],
                ),
                NotificationCategory(
                  title: 'SMS Notifications',
                  options: [
                    NotificationOption(
                      label: 'Order Updates',
                      value: _notificationPrefs['sms']['order_updates'] ?? true,
                      onChanged: (value) => _updatePreference('sms', 'order_updates', value),
                    ),
                    NotificationOption(
                      label: 'Promotions',
                      value: _notificationPrefs['sms']['promotions'] ?? false,
                      onChanged: (value) => _updatePreference('sms', 'promotions', value),
                    ),
                    NotificationOption(
                      label: 'Delivery Status',
                      value: _notificationPrefs['sms']['delivery_status'] ?? true,
                      onChanged: (value) => _updatePreference('sms', 'delivery_status', value),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                SaveChangesButton(
                  isLoading: _isLoading,
                  onPressed: _savePreferences,
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ],
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
                  onPressed: () => Navigator.pop(
                    context,

                  ),
                ),
              ),
            ),
          ),

          // Centered title
          Padding(
            padding: const EdgeInsets.only(top: 60.0,bottom: 28),
            child: Center(
              child: Text(
                'Notification preferences',
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


class NotificationCategory extends StatelessWidget {
  final String title;
  final List<NotificationOption> options;

  const NotificationCategory({required this.title, required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 8),
          Column(
            children: options.map((option) => NotificationToggle(option: option)).toList(),
          ),
        ],
      ),
    );
  }
}

class NotificationOption {
  final String label;
  bool value;
  final Function(bool) onChanged;

  NotificationOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class NotificationToggle extends StatelessWidget {
  final NotificationOption option;

  const NotificationToggle({required this.option});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            option.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
          Switch(
            value: option.value,
            onChanged: (bool newValue) {
              option.onChanged(newValue);
            },
            activeColor: Color(0xFF0B7F40),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Color(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }
}

class SaveChangesButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const SaveChangesButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0B7F40),
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? CircularProgressIndicator(color: Colors.white)
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

import 'package:flutter/material.dart';

import '../logistics/notificationstatus.dart';



class LanguageSelectionPage extends StatefulWidget {
  @override
  _LanguageSelectionPageState createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                LanguageOption(
                  language: 'English',
                  isSelected: _selectedLanguage == 'English',
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'English';
                    });
                  },
                ),
                LanguageOption(
                  language: 'Hausa',
                  isSelected: _selectedLanguage == 'Hausa',
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'Hausa';
                    });
                  },
                ),
                LanguageOption(
                  language: 'Yoruba',
                  isSelected: _selectedLanguage == 'Yoruba',
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'Yoruba';
                    });
                  },
                ),
                LanguageOption(
                  language: 'Igbo',
                  isSelected: _selectedLanguage == 'Igbo',
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'Igbo';
                    });
                  },
                ),
              ],
            ),
          ),
          BottomNavigationBarComponent(),
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
                'Language Preference',
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


class LanguageOption extends StatelessWidget {
  final String language;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageOption({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF9EF84A) : Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              language,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1E293B),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Color(0xFF0B3D3A) : Color(0xFF94A3B8),
            ),
          ],
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

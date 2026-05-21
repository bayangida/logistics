import 'package:flutter/material.dart';

import '../logistics/notificationstatus.dart';


class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/about.png', // Placeholder for logo
                          width: 100,
                          height: 100,
                        ),
                        SizedBox(height: 8),

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
                    context

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
                'Earnings',
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


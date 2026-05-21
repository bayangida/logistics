import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bayangida_logistics/providers/tracking-provider.dart';
import 'package:bayangida_logistics/tracking_flow.dart';
import 'app_navigator.dart';

class BottomNavigationBarComponent extends StatelessWidget {
  final int currentIndex;

  const BottomNavigationBarComponent({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -3.33), // Elevates the bar upward by 3.33px
      child: Container(
        width: 343, // Exact width
        height: 69.99, // Exact height
        decoration: BoxDecoration(
          color: const Color(0xFF042E22), // Background: #042E22
          borderRadius: BorderRadius.circular(60), // Rounded edges (20px radius)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2), // Subtle upward shadow
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Dashboard', context),
            _buildNavItem(1, Icons.shopping_cart, 'Orders', context),
            _buildNavItem(2, Icons.local_shipping, 'Tracking', context),
            _buildNavItem(3, Icons.person, 'Profile', context),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTabTap(index, context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: currentIndex == index ? const Color(0xFF9EF84A) : const Color(0xFF0B7F40),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: currentIndex == index ? const Color(0xFF9EF84A) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTabTap(int index, BuildContext context) {
    if (currentIndex == index) return;

    switch (index) {
      case 0:
        AppNavigator.navigateToHome(context);
        break;
      case 1:
        AppNavigator.navigateToOrders(context);
        break;
      case 2:
        final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
        if (trackingProvider.currentOrderId != null) {
          TrackingFlowManager.startTrackingFlow(context, trackingProvider.currentOrderId!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active delivery to track')),
          );
        }
        break;
      case 3:
        AppNavigator.navigateToProfile(context);
        break;
    }
  }
}
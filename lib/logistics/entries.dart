import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_navigator.dart';
import '../bottom_nav_bar.dart';
import 'notificationstatus.dart';

class Deliveryentries extends StatelessWidget {
  final String orderId;

  const Deliveryentries({Key? key, required this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF042E22),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Order not found', style: TextStyle(color: Colors.white)));
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;
          return _DeliveryContent(order: order, orderId: orderId);
        },
      ),
    );
  }
}

class _DeliveryContent extends StatelessWidget {
  final Map<String, dynamic> order;
  final String orderId;

  const _DeliveryContent({required this.order, required this.orderId});

  String _formatAddress(dynamic addressData) {
    if (addressData == null) return 'Not specified';

    if (addressData is String) {
      return addressData;
    }

    if (addressData is Map<String, dynamic>) {
      final street = addressData['address'] ?? addressData['street'] ?? '';
      final city = addressData['city'] ?? '';
      final state = addressData['state'] ?? '';
      final country = addressData['country'] ?? '';

      List<String> addressParts = [];
      if (street.isNotEmpty) addressParts.add(street);
      if (city.isNotEmpty) addressParts.add(city);
      if (state.isNotEmpty) addressParts.add(state);
      if (country.isNotEmpty) addressParts.add(country);

      return addressParts.join(', ');
    }

    return 'Not specified';
  }
  String _getPickupLocation(Map<String, dynamic> order) {
    if (order['pickupLocation'] != null) {
      if (order['pickupLocation'] is Map) {
        final pickup = order['pickupLocation'] as Map<String, dynamic>;
        return _formatAddress(pickup);
      }
    }

    // Fallback to address field
    final address = order['address'];
    if (address is Map) {
      return _formatAddress(address as Map<String, dynamic>);
    }

    return 'Unknown Location';
  }

  String _getDeliveryLocation(Map<String, dynamic> order) {
    // Method 1: Check receiverAddress (based on your Firestore structure)
    if (order['receiverAddress'] != null) {
      if (order['receiverAddress'] is Map) {
        final receiver = order['receiverAddress'] as Map<String, dynamic>;
        return _formatAddress(receiver);
      }
    }

    // Method 2: Fallback to address field
    final address = order['address'];
    if (address is Map) {
      return _formatAddress(address as Map<String, dynamic>);
    }

    return 'Unknown Location';
  }
  String _getSellerName(Map<String, dynamic> order) {
    return order['sellerName'] ??
        order['farmerName'] ??
        'Seller';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 54), // Space for status bar
            Header(title: 'Delivery'),
            StepIndicator(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
    SenderDetails(
    name: _getSellerName(order),
    address: _getPickupLocation(order),
    ),
                  SizedBox(height: 16),
                  ReceiverDetails(
                    name: order['buyerName'] ?? 'Customer',
                    address: _getDeliveryLocation(order), // Use the formatted address
                  ),
                  SizedBox(height: 16),
                  AddVehicleButton(orderId: orderId),
                  SizedBox(height: 80,)
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 20,
          bottom: 20,
          right: 20,
          child: BottomNavigationBarComponent(currentIndex: 2),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _fetchSellerDetails(String sellerId) async {
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();

      if (sellerDoc.exists) {
        return sellerDoc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching seller details: $e');
      return null;
    }
  }

  String _formatSellerAddress(Map<String, dynamic> sellerData) {
    final address = sellerData['address'] ?? {};
    if (address is Map<String, dynamic>) {
      return _formatAddress(address);
    }
    return 'Address not available';
  }
}

class Header extends StatelessWidget {
  final String title;

  const Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Back button aligned to the left
        Align(
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

        // Centered title
        Center(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),

        // Notification icon aligned to the right
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
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
    );
  }
}

class StepIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StepItem(label: 'STEP 1', description: 'Basic Details', isActive: true),
          StepItem(label: 'STEP 2', description: 'Information', isActive: true),
          StepItem(label: 'STEP 3', description: 'Confirmation', isActive: false),
        ],
      ),
    );
  }
}

class StepItem extends StatelessWidget {
  final String label;
  final String description;
  final bool isActive;

  const StepItem({
    required this.label,
    required this.description,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isActive ? Color(0xFF9EF84A) : Colors.white.withOpacity(0.5),
          size: 28,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        Text(
          description,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class SenderDetails extends StatelessWidget {
  final String name;
  final String address;

  const SenderDetails({
    required this.name,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF0B3D3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF9EF84A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader('Sender details'),
          SizedBox(height: 8),
          _buildReadOnlyField('Name', name),
          SizedBox(height: 8),
          _buildReadOnlyField('Address', address),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF042E22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class ReceiverDetails extends StatelessWidget {
  final String name;
  final String address;

  const ReceiverDetails({
    required this.name,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF0B3D3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF9EF84A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader('Receiver details'),
          SizedBox(height: 8),
          _buildReadOnlyField('Name', name),
          SizedBox(height: 8),
          _buildReadOnlyField('Address', address),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF042E22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class AddVehicleButton extends StatelessWidget {
  final String orderId;

  const AddVehicleButton({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          AppNavigator.navigateToDeliveryEnd(context, orderId: orderId);
        },
        icon: Icon(Icons.arrow_forward, color: Colors.white),
        label: Text(
          'Submit',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0B7F40),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
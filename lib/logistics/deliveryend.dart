import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../bottom_nav_bar.dart';
import '../app_navigator.dart';
import 'notificationstatus.dart';

class DeliveryPageend extends StatefulWidget {
  final String orderId;

  const DeliveryPageend({Key? key, required this.orderId}) : super(key: key);

  @override
  _DeliveryPageendState createState() => _DeliveryPageendState();
}

class _DeliveryPageendState extends State<DeliveryPageend> {
  late Map<String, dynamic> order;
  bool isLoading = true;
  String? pickupAddress;
  String? deliveryAddress;
  String? estimatedTime;
  double? distance;
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    try {
      // Fetch order data
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      setState(() {
        order = orderDoc.data() as Map<String, dynamic>;
      });

      // Get current position
      await _getCurrentLocation();

      // Get seller address
      final sellerAddress = await _fetchSellerAddress(order['sellerId']);
      pickupAddress = _formatAddress(sellerAddress);

      // Delivery address comes from order
      deliveryAddress = order['address'];

      // Calculate distance and estimated time
      if (currentPosition != null && sellerAddress != null) {
        await _calculateDistanceAndTime(
          sellerAddress['latitude'],
          sellerAddress['longitude'],
          currentPosition!.latitude,
          currentPosition!.longitude,
        );
      }

      setState(() {
        isLoading = false;
      });

    } catch (e) {
      print('Error loading order data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading delivery data: $e')),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchSellerAddress(String sellerId) async {
    try {
      final addressDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('addresses')
          .limit(1)
          .get();

      if (addressDoc.docs.isNotEmpty) {
        return addressDoc.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error fetching seller address: $e');
      return null;
    }
  }

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Address not available';
    return '${address['address']}, ${address['city']}, ${address['state']}, ${address['country']}';
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _calculateDistanceAndTime(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) async {
    try {
      // Calculate distance in meters
      double distanceInMeters = await Geolocator.distanceBetween(
        startLat, startLng, endLat, endLng,
      );

      // Convert to kilometers
      double distanceInKm = distanceInMeters / 1000;

      // Estimate time (assuming average walking speed of 5 km/h)
      double hours = distanceInKm / 5;
      int minutes = (hours * 60).round();

      setState(() {
        distance = distanceInKm;
        estimatedTime = minutes > 60
            ? '${(minutes / 60).round()} hours ${minutes % 60} min'
            : '$minutes min';
      });
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF042E22),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final items = order['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items[0] : {};
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Scaffold(
      backgroundColor: Color(0xFF042E22),
      body: Stack(
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
                DeliveryLocation(
                  pickupAddress: pickupAddress ?? 'Loading...',
                  deliveryAddress: deliveryAddress ?? 'Loading...',
                  estimatedTime: estimatedTime ?? 'Calculating...',
                ),
                SizedBox(height: 16),
                OrderSummary(
                  items: items,
                  createdAt: createdAt,
                  totalAmount: order['totalAmount'] ?? 0,
                  distance: distance,
                ),
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
    ]));
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
              onPressed: () => Navigator.pop(
                context,

              ),
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
          StepItem(label: 'STEP 3', description: 'Confirmation', isActive: true),
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

class DeliveryLocation extends StatelessWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final String estimatedTime;

  const DeliveryLocation({
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.estimatedTime,
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
          Text(
            'Delivery Location',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          _buildLocationRow(
            icon: Icons.location_on,
            title: 'Pick up',
            subtitle: 'Sender address',
            address: pickupAddress,
          ),
          Divider(color: Colors.white.withOpacity(0.3)),
          _buildLocationRow(
            icon: Icons.location_on,
            title: 'Delivery to',
            subtitle: 'Receiver address',
            address: deliveryAddress,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF9EF84A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Estimated time: $estimatedTime',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({required IconData icon, required String title, required String subtitle, required String address}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF9EF84A), size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  address,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderSummary extends StatelessWidget {
  final List<dynamic> items;
  final DateTime createdAt;
  final dynamic totalAmount;
  final double? distance;

  const OrderSummary({
    required this.items,
    required this.createdAt,
    required this.totalAmount,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final firstItem = items.isNotEmpty ? items[0] : {};
    final estimatedDeliveryTime = createdAt.add(Duration(hours: 2));
    final deliveryTime = DateFormat('HH:mm').format(estimatedDeliveryTime);

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
          Text(
            'Order Summary',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          _buildSummaryRow('Item', firstItem['productName'] ?? 'N/A'),
          _buildSummaryRow('Quantity', '${firstItem['quantity']} kg'),
          if (distance != null)
            _buildSummaryRow('Distance', '${distance!.toStringAsFixed(1)} km'),
          _buildSummaryRow('Pick up time', '${DateFormat('HH:mm').format(createdAt)}'),
          _buildSummaryRow('Delivery time', deliveryTime),
          _buildSummaryRow('Payment', _formatPrice(totalAmount)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final num amount = price is String ? double.tryParse(price) ?? 0 : price;
    return '₦${NumberFormat('#,##0.00').format(amount)}';
  }
}
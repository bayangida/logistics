import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../app_navigator.dart';
import '../bottom_nav_bar.dart';
import '../providers/tracking-provider.dart';
import '../providers/user_provider.dart';
import 'notificationstatus.dart';
import 'orderhistory.dart';

class DeliveryPage extends StatefulWidget {
  final String orderId;

  const DeliveryPage({Key? key, required this.orderId}) : super(key: key);

  @override
  _DeliveryPageState createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  late Map<String, dynamic> order;
  bool isLoading = true;
  bool isCalculatingDistance = false;
  String? pickupAddress;
  String? deliveryAddress;
  String? estimatedTime;
  double? distance;
  Position? currentPosition;
  String? errorMessage;

  static const String _apiKey = 'AIzaSyD7K_phmycqudRGCnt_DpIAC9i4BWgy5ds';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

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

      // Get addresses directly from order data
      pickupAddress = _getPickupLocation(order);
      deliveryAddress = _getDeliveryLocation(order);

      // Get current position
      await _getCurrentLocation();

      // Calculate distance and estimated time
      if (pickupAddress != null && deliveryAddress != null) {
        await _calculateDistanceAndTime();
      }

      setState(() {
        isLoading = false;
      });

    } catch (e) {
      print('Error loading order data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading delivery data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading delivery data: $e')),
      );
    }
  }

  String _getPickupLocation(Map<String, dynamic> order) {
    if (order['pickupLocation'] != null) {
      if (order['pickupLocation'] is Map) {
        final pickup = order['pickupLocation'] as Map<String, dynamic>;
        return _buildFullAddressString(pickup);
      }
    }

    // Fallback to address field
    final address = order['address'];
    if (address is Map) {
      return _buildFullAddressString(address as Map<String, dynamic>);
    }

    return 'Unknown Location';
  }

  String _getDeliveryLocation(Map<String, dynamic> order) {
    // Method 1: Check receiverAddress (based on your Firestore structure)
    if (order['receiverAddress'] != null) {
      if (order['receiverAddress'] is Map) {
        final receiver = order['receiverAddress'] as Map<String, dynamic>;
        return _buildFullAddressString(receiver);
      }
    }

    // Method 2: Fallback to other address fields
    final address = order['address'];
    if (address is Map) {
      return _buildFullAddressString(address as Map<String, dynamic>);
    }

    return 'Unknown Location';
  }

  String _buildFullAddressString(Map<String, dynamic> address) {
    final parts = <String>[];

    // Add street address
    if (address['address'] != null && (address['address'] as String).isNotEmpty) {
      parts.add(address['address'] as String);
    }

    if (address['street'] != null && (address['street'] as String).isNotEmpty) {
      parts.add(address['street'] as String);
    }

    // Add city
    if (address['city'] != null && (address['city'] as String).isNotEmpty) {
      parts.add(address['city'] as String);
    }

    // Add state
    if (address['state'] != null && (address['state'] as String).isNotEmpty) {
      parts.add(address['state'] as String);
    }

    // Add zip code if available
    if (address['zipCode'] != null && (address['zipCode'] as String).isNotEmpty) {
      parts.add(address['zipCode'] as String);
    }

    // Add country (default to Nigeria)
    final country = address['country'] as String? ?? 'Nigeria';
    parts.add(country);

    return parts.join(', ');
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print('Error getting current location: $e');
      // Continue without current location - we'll use pickup address as origin
    }
  }

  Future<void> _calculateDistanceAndTime() async {
    try {
      setState(() {
        isCalculatingDistance = true;
        errorMessage = null;
      });

      // Use current position as origin if available, otherwise use pickup address
      final String origin;
      if (currentPosition != null) {
        origin = '${currentPosition!.latitude},${currentPosition!.longitude}';
      } else {
        origin = pickupAddress!;
      }

      final String destination = deliveryAddress!;

      print('Calculating route: $origin → $destination');

      final result = await _getDistanceAndDuration(
        origin: origin,
        destination: destination,
      );

      final distanceInMeters = result['distanceInMeters'] as int;
      final durationInSeconds = result['durationInSeconds'] as int;

      setState(() {
        distance = distanceInMeters / 1000.0;
        estimatedTime = _formatDuration(durationInSeconds);
        isCalculatingDistance = false;
      });

      print('✓ Distance: ${distance!.toStringAsFixed(2)} km');
      print('✓ Estimated time: $estimatedTime');

    } catch (e) {
      print('Error calculating distance: $e');
      setState(() {
        isCalculatingDistance = false;
        errorMessage = 'Failed to calculate distance: $e';
        distance = null;
        estimatedTime = 'Unable to calculate';
      });
    }
  }

  /// Get distance and duration between two addresses using Google Maps Distance Matrix API
  Future<Map<String, int>> _getDistanceAndDuration({
    required String origin,
    required String destination,
  }) async {
    try {
      final Uri url = Uri.parse(
          '$_baseUrl?'
              'origins=${Uri.encodeComponent(origin)}&'
              'destinations=${Uri.encodeComponent(destination)}&'
              'mode=driving&'
              'language=en&'
              'region=ng&'
              'key=$_apiKey'
      );

      print('Calling Google Maps Distance Matrix API...');

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Google Maps API returned error: ${response.statusCode}');
      }

      final Map<String, dynamic> data = json.decode(response.body);

      // Check overall API status
      if (data['status'] != 'OK') {
        final errorMessage = data['error_message'] ?? 'Unknown error';
        throw Exception('Google Maps API error: ${data['status']} - $errorMessage');
      }

      // Check if we have valid rows and elements
      if (data['rows'] == null || (data['rows'] as List).isEmpty) {
        throw Exception('No route data returned from Google Maps API');
      }

      final row = data['rows'][0];
      if (row['elements'] == null || (row['elements'] as List).isEmpty) {
        throw Exception('No distance data returned from Google Maps API');
      }

      final element = row['elements'][0];
      final elementStatus = element['status'];

      // Check element status
      if (elementStatus != 'OK') {
        String errorMessage;
        switch (elementStatus) {
          case 'NOT_FOUND':
            errorMessage = 'One or both addresses could not be found. Please verify the addresses.';
            break;
          case 'ZERO_RESULTS':
            errorMessage = 'No route could be found between the addresses.';
            break;
          case 'MAX_ROUTE_LENGTH_EXCEEDED':
            errorMessage = 'The route is too long to calculate.';
            break;
          default:
            errorMessage = 'Could not calculate route: $elementStatus';
        }
        throw Exception(errorMessage);
      }

      // Extract distance and duration
      if (element['distance'] == null || element['duration'] == null) {
        throw Exception('Distance or duration data missing from API response');
      }

      final distance = element['distance'];
      final duration = element['duration'];

      final distanceValue = distance['value'];
      final durationValue = duration['value'];

      if (distanceValue == null || durationValue == null) {
        throw Exception('Distance or duration value is null');
      }

      final int distanceInMeters = distanceValue is int ? distanceValue : (distanceValue as num).toInt();
      final int durationInSeconds = durationValue is int ? durationValue : (durationValue as num).toInt();

      if (distanceInMeters <= 0) {
        throw Exception('Invalid distance calculated (0 meters). Please verify addresses.');
      }

      return {
        'distanceInMeters': distanceInMeters,
        'durationInSeconds': durationInSeconds,
      };

    } catch (e) {
      print('Google Maps API error: $e');
      rethrow;
    }
  }

  /// Format duration in seconds to human-readable string
  String _formatDuration(int durationInSeconds) {
    if (durationInSeconds <= 0) {
      return 'Unknown duration';
    }

    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours hr ${minutes} min';
      }
      return '$hours hr';
    } else {
      return '$minutes min';
    }
  }

  void _retryDistanceCalculation() {
    if (pickupAddress != null && deliveryAddress != null) {
      _calculateDistanceAndTime();
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
                    // Error message if any
                    if (errorMessage != null)
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (pickupAddress != null && deliveryAddress != null)
                              TextButton(
                                onPressed: _retryDistanceCalculation,
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF9EF84A),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    DeliveryLocation(
                      pickupAddress: pickupAddress ?? 'Loading...',
                      deliveryAddress: deliveryAddress ?? 'Loading...',
                      estimatedTime: estimatedTime ?? 'Calculating...',
                      isCalculating: isCalculatingDistance,
                    ),
                    SizedBox(height: 16),
                    DeliveryTime(
                      status: order['status'] ?? 'pending',
                      createdAt: createdAt,
                      distance: distance,
                      isCalculating: isCalculatingDistance,
                    ),
                    SizedBox(height: 16),
                    AddVehicleButton(
                      orderId: widget.orderId,
                      status: order['status'] ?? 'pending',
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
            child: BottomNavigationBarComponent(currentIndex: 1),
          ),
        ],
      ),
    );
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

class DeliveryLocation extends StatelessWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final String estimatedTime;
  final bool isCalculating;

  const DeliveryLocation({
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.estimatedTime,
    this.isCalculating = false,
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
          Row(
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
              if (isCalculating) ...[
                SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9EF84A),
                  ),
                ),
              ],
            ],
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
            child: isCalculating
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Calculating...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ],
            )
                : Text(
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
          Icon(Icons.edit, color: Color(0xFF9EF84A), size: 20),
        ],
      ),
    );
  }
}

class AddVehicleButton extends StatelessWidget {
  final String orderId;
  final String status;

  const AddVehicleButton({
    required this.orderId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (status == 'shipped') {
            _updateOrderStatus(context, 'delivered');
          } else {
            AppNavigator.navigateToDeliveryEntries(context, orderId: orderId);
          }
        },
        icon: Icon(
          status == 'shipped' ? Icons.check : Icons.arrow_forward,
          color: Colors.white,
        ),
        label: Text(
          status == 'shipped' ? 'Mark as Delivered' : 'Next',
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

  Future<void> _updateOrderStatus(BuildContext context, String newStatus) async {
    try {
      // Get the TrackingProvider
      final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(), // Add delivery timestamp
      });

      // Complete tracking - this will clear currentOrderId and currentStep
      trackingProvider.completeTracking();

      // Create notification
      await _createDeliveryNotification(newStatus);

      // Navigate back to manage orders page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => ManageOrdersPage()),
            (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order delivered successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status: $e')),
      );
    }
  }

  Future<void> _createDeliveryNotification(String status) async {
    try {
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      final order = orderDoc.data() as Map<String, dynamic>;

      String title = '';
      String message = '';

      if (status == 'delivered') {
        title = 'Delivery Completed';
        message = 'Your order #${orderId.substring(0, 8)} has been delivered';
      } else {
        title = 'Delivery Update';
        message = 'Your order #${orderId.substring(0, 8)} status has been updated';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': order['userId'],
        'orderId': orderId,
        'type': 'delivery_update',
        'title': title,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }
}
class DeliveryTime extends StatelessWidget {
  final String status;
  final DateTime createdAt;
  final double? distance;
  final bool isCalculating;

  const DeliveryTime({
    required this.status,
    required this.createdAt,
    this.distance,
    this.isCalculating = false,
  });

  @override
  Widget build(BuildContext context) {
    final estimatedDeliveryTime = createdAt.add(Duration(hours: 2));
    final formattedDeliveryTime = '${estimatedDeliveryTime.hour}:${estimatedDeliveryTime.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: Container(
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
                Row(
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isCalculating) ...[
                      SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF9EF84A),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'From pickup to delivery',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  isCalculating
                      ? 'Calculating...'
                      : distance != null
                      ? '${distance!.toStringAsFixed(1)} km'
                      : 'Unable to calculate',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Estimated by $formattedDeliveryTime',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Container(
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
                  'Status',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Current status:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Updated: ${DateTime.now().difference(createdAt).inMinutes} min ago',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'shipped':
        return Color(0xFFFFC107); // Amber
      case 'delivered':
        return Color(0xFF4CAF50); // Green
      case 'cancelled':
        return Color(0xFFF44336); // Red
      default:
        return Color(0xFF2196F3); // Blue
    }
  }
}
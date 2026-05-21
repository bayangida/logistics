import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../bottom_nav_bar.dart';
import '../app_navigator.dart';
import 'notificationstatus.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final DocumentReference orderRef;

  const OrderDetailsPage({
    required this.order,
    required this.orderRef,
    Key? key,
  }) : super(key: key);

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool showSuccessMessage = false;
  late String currentStatus;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order['status'] ?? 'pending';
  }

  String _formatAddress(dynamic addressData) {
    if (addressData == null) return 'Not specified';

    if (addressData is String) {
      return addressData;
    }

    if (addressData is Map<String, dynamic>) {
      final street = addressData['address'] ?? '';
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
        return order['pickupLocation']['city'] ??
            order['pickupLocation']['address'] ??
            'Unknown Location';
      }
    }

    final address = order['address'];
    if (address is Map) {
      return address['city'] ?? address['address'] ?? 'Unknown Location';
    }

    return 'Unknown Location';
  }

  String _getDeliveryLocation(Map<String, dynamic> order) {
    if (order['deliveryLocation'] != null) {
      if (order['deliveryLocation'] is Map) {
        return order['deliveryLocation']['city'] ??
            order['deliveryLocation']['address'] ??
            'Unknown Location';
      }
    }

    final customerAddress = order['customerAddress'];
    if (customerAddress is Map) {
      return customerAddress['city'] ?? customerAddress['address'] ?? 'Unknown Location';
    }

    return 'Unknown Location';
  }

  String _getCustomerName(Map<String, dynamic> order) {
    return order['customerName'] ??
        order['buyerName'] ??
        'Customer';
  }

  String _formatPrice(num price) {
    return price.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
  }

  void _updateStatus(String newStatus) async {
    try {
      setState(() => isLoading = true);

      await widget.orderRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        currentStatus = newStatus;
        showSuccessMessage = true;
      });

      // Create notifications based on status change
      if (newStatus == 'shipped') {
        await _createDeliveryNotification();
      } else if (newStatus == 'delivered') {
        await _createDeliveryCompletedNotification();
      }

      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() => showSuccessMessage = false);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _createDeliveryNotification() async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.order['farmerId'], // Farmer's ID
        'orderId': widget.orderRef.id,
        'type': 'delivery_update',
        'title': 'Delivery Started',
        'message': 'Your order #${widget.order['orderId']?.toString().substring(0, 8) ?? widget.orderRef.id.substring(0, 8)} has been picked up by the driver',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> _createDeliveryCompletedNotification() async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.order['farmerId'], // Farmer's ID
        'orderId': widget.orderRef.id,
        'type': 'delivery_completed',
        'title': 'Delivery Completed',
        'message': 'Your order #${widget.order['orderId']?.toString().substring(0, 8) ?? widget.orderRef.id.substring(0, 8)} has been delivered',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Widget _buildStatusStep(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Color(0xFF9EF84A) : Colors.grey,
            ),
            child: isActive ? Icon(Icons.check, size: 16, color: Colors.black) : null,
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: isActive ? Color(0xFF9EF84A) : Colors.white70,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Divider(color: Color(0xFF0B7F40)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final date = (widget.order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final estimatedDelivery = (widget.order['estimatedDeliveryDate'] as Timestamp?)?.toDate();
    final formattedDeliveryDate = estimatedDelivery != null
        ? '${estimatedDelivery.day}/${estimatedDelivery.month}/${estimatedDelivery.year}'
        : 'Not specified';

    return Scaffold(
      backgroundColor: const Color(0xFF042E22),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Container(
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
                          const SizedBox(width: 20),
                          Text(
                            'Order details',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Order number
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Order no. #${widget.order['orderId']?.toString().substring(0, 8) ?? 'N/A'}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          color: const Color(0xFF9EF84A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Product Images
                    if (items.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Container(
                              width: 353,
                              height: 153,
                              margin: EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF0B7F40),
                                  width: 1,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(item['productImage'] ?? 'https://via.placeholder.com/120'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    SizedBox(height: 20),

                    // Product Details Section
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF042E22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0B7F40),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product Details',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),

                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Name',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      item['productName'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Quantity',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      "${item['quantity'] as num}${item['unit'] as num}",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Price per unit',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₦${_formatPrice(item['price'] as num)}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Divider(color: Color(0xFF0B7F40)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),



                    SizedBox(height: 16),

                    // Delivery Information Section
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF042E22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0B7F40),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Information',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),

                          _buildInfoRow('Order Date', formattedDate),
                          _buildInfoRow('Estimated Delivery', formattedDeliveryDate),
                          _buildInfoRow('Customer Name', _getCustomerName(widget.order)),
                          _buildInfoRow('Pickup Location', _getPickupLocation(widget.order)),
                          _buildInfoRow('Delivery Location', _getDeliveryLocation(widget.order)),
                          _buildInfoRow('Delivery Address', _formatAddress(widget.order['address'])),
                          _buildInfoRow('Total Amount', '₦${_formatPrice(widget.order['totalAmount'] as num? ?? 0)}'),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            if (isLoading)
              Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: BottomNavigationBarComponent(currentIndex: 1),
      ),
    );
  }
}

class Header extends StatelessWidget {
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
            'Order details',
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
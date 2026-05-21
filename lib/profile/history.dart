import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


import '../logistics/notificationstatus.dart';
import 'menuselect.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('MMMM dd, yyyy');

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: userId != null
                  ? _firestore
                  .collection('orders')
                  .where('driverId', isEqualTo: userId)
                  .where('status', isEqualTo: 'completed')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading orders',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No completed orders yet',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Color(0xFF475569),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your completed orders will appear here',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!.docs;

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final data = order.data() as Map<String, dynamic>;
                    final orderDate = (data['createdAt'] as Timestamp).toDate();
                    final items = data['items'] as List<dynamic>? ?? [];

                    // Get product names for display
                    String productDisplayName;
                    if (items.isEmpty) {
                      productDisplayName = 'No items';
                    } else if (items.length == 1) {
                      productDisplayName = items[0]['productName'] ?? items[0]['name'] ?? 'Unknown Product';
                    } else {
                      productDisplayName = '${items[0]['productName'] ?? items[0]['name'] ?? 'Unknown Product'} + ${items.length - 1} more';
                    }

                    // Get first item image if available
                    String? imageUrl;
                    if (items.isNotEmpty) {
                      imageUrl = items[0]['productImage'] ?? items[0]['imageUrl'];
                    }

                    return HistoryItem(
                      orderId: order.id,
                      productName: productDisplayName,
                      orderNumber: data['orderId'] ?? data['orderNumber'] ?? 'N/A',
                      date: _dateFormat.format(orderDate),
                      totalAmount: (data['totalAmount'] ?? 0).toStringAsFixed(2),
                      imageUrl: imageUrl,
                      onReceiptPressed: () {
                        _showReceipt(context, order.id, data);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceipt(BuildContext context, String orderId, Map<String, dynamic> orderData) async {
    final items = orderData['items'] as List<dynamic>? ?? [];
    final orderDate = (orderData['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMMM dd, yyyy - HH:mm').format(orderDate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.receipt, color: Color(0xFF0B7F40)),
            SizedBox(width: 8),
            Text(
              'Order Receipt',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF042E22),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Info
                _buildReceiptRow('Order ID:', orderData['orderId'] ?? 'N/A'),
                _buildReceiptRow('Date:', formattedDate),
                _buildReceiptRow('Status:', 'Completed'),

                SizedBox(height: 16),

                // Items
                Text(
                  'Items:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF042E22),
                  ),
                ),
                SizedBox(height: 8),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['productName'] ?? item['name'] ?? 'Unknown'} (${item['quantity']}kg)',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Text(
                        '₦${(item['price'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF042E22),
                        ),
                      ),
                    ],
                  ),
                )).toList(),

                SizedBox(height: 16),
                Divider(color: Color(0xFFE2E8F0)),
                SizedBox(height: 8),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF042E22),
                      ),
                    ),
                    Text(
                      '₦${(orderData['totalAmount'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B7F40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF0B7F40),
            ),
            child: Text(
              'Close',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
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
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF042E22),
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
            padding: const EdgeInsets.only(top: 60.0, bottom: 28),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Centered title
          Padding(
            padding: const EdgeInsets.only(top: 60.0, bottom: 28),
            child: Center(
              child: Text(
                'Order History',
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
            padding: const EdgeInsets.only(
                top: 60.0,
                bottom: 28,
                right: 9
            ),
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

class HistoryItem extends StatelessWidget {
  final String orderId;
  final String productName;
  final String orderNumber;
  final String date;
  final String totalAmount;
  final String? imageUrl;
  final VoidCallback onReceiptPressed;

  const HistoryItem({
    required this.orderId,
    required this.productName,
    required this.orderNumber,
    required this.date,
    required this.totalAmount,
    this.imageUrl,
    required this.onReceiptPressed,
  });

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
        border: Border.all(
          color: Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              image: imageUrl != null
                  ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: imageUrl == null
                ? Center(
              child: Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFF64748B),
                size: 32,
              ),
            )
                : null,
          ),

          SizedBox(width: 16),

          // Order Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  productName,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 6),

                // Order Number
                Text(
                  'Order #${orderNumber.length > 8 ? orderNumber.substring(0, 8) : orderNumber}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),

                SizedBox(height: 6),

                // Date and Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),

                  ],
                ),
                Text(
                  '₦$totalAmount',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B7F40),
                  ),
                ),

                SizedBox(height: 12),

                // Receipt Button
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: onReceiptPressed,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF0B7F40)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt, size: 16, color: Color(0xFF0B7F40)),
                        SizedBox(width: 6),
                        Text(
                          'Receipt',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0B7F40),
                          ),
                        ),
                      ],
                    ),
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
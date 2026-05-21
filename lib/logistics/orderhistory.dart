import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../bottom_nav_bar.dart';
import '../app_navigator.dart';
import '../providers/tracking-provider.dart';
import '../providers/user_provider.dart';
import 'notificationstatus.dart';

class ManageOrdersPage extends StatefulWidget {
  @override
  _ManageOrdersPageState createState() => _ManageOrdersPageState();
}

class _ManageOrdersPageState extends State<ManageOrdersPage> {
  int _selectedTab = 0; // 0 for New Orders, 1 for Orders History
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Color(0xFF042E22),
      body: Column(
        children: [
          SizedBox(height: 54), // Space for status bar
          Header(),
          SizedBox(height: 16),
          // Availability Toggle Button
          _buildAvailabilityToggle(userProvider),
          SizedBox(height: 16),
          // New Tab Design
          TabSection(
            selectedTab: _selectedTab,
            onTabSelected: (index) {
              setState(() {
                _selectedTab = index;
              });
            },
          ),
          SizedBox(height: 16),
          // Tab Content
          Expanded(
            child: _selectedTab == 0
                ? _buildOrdersList(currentUserId, ['processing', 'shipped'])
                : _buildOrdersList(currentUserId, ['completed', 'delivered']),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: BottomNavigationBarComponent(currentIndex: 1),
      ),
    );
  }

  Widget _buildAvailabilityToggle(UserProvider userProvider) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('drivers').doc(userProvider.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Handle case where driver document doesn't exist
          return _buildDefaultAvailabilityButton(userProvider, false);
        }

        // Explicitly cast the data to Map<String, dynamic>
        final driverData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final isAvailable = driverData['isAvailable'] as bool? ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAvailable ? Color(0xFF0B7F40) : Colors.grey,
              minimumSize: Size(double.infinity, 50),
            ),
            onPressed: () => _toggleAvailability(userProvider, !isAvailable),
            child: Text(
              isAvailable ? 'You Are Available (Turn Off)' : 'Turn On Availability',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for when driver document doesn't exist
  Widget _buildDefaultAvailabilityButton(UserProvider userProvider, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isAvailable ? Color(0xFF0B7F40) : Colors.grey,
          minimumSize: Size(double.infinity, 50),
        ),
        onPressed: () => _toggleAvailability(userProvider, !isAvailable),
        child: Text(
          isAvailable ? 'You Are Available (Turn Off)' : 'Turn On Availability',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(UserProvider userProvider, bool newStatus) async {
    try {
      // Update in drivers collection
      await _firestore.collection('drivers').doc(userProvider.uid).update({
        'isAvailable': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Also update in users collection for consistency
      await _firestore.collection('users').doc(userProvider.uid).update({
        'isAvailable': newStatus,
      });

      // Refresh the UI
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update availability, upload fleet first!!!')),
      );
    }
  }
  // Add this method in _OrderDetailsPageState class

  Widget _buildOrdersList(String? userId, List<String> statuses) {
    if (userId == null) {
      return Center(
        child: Text(
          'User not authenticated',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: userId)
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF9EF84A)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              statuses.contains('delivered')
                  ? 'No completed orders yet'
                  : 'No new orders available',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final order = orderDoc.data() as Map<String, dynamic>;
            return OrderCard(
              order: order,
              orderRef: orderDoc.reference,
            );
          },
        );
      },
    );
  }
}

// New TabSection Widget (copied from your second code)
class TabSection extends StatelessWidget {
  final int selectedTab;
  final Function(int) onTabSelected;

  const TabSection({
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Tab 1: New Orders (Expands to half width)
            Expanded(
              child: GestureDetector(
                onTap: () => onTabSelected(0),
                child: Column(
                  children: [
                    Text(
                      'New Orders',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 24 / 18,
                        color: selectedTab == 0 ? Colors.white : Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Tab 2: Order History (Expands to half width)
            Expanded(
              child: GestureDetector(
                onTap: () => onTabSelected(1),
                child: Column(
                  children: [
                    Text(
                      'Orders History',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 24 / 18,
                        color: selectedTab == 1 ? Colors.white : Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Full-width underline indicators (edge-to-edge)
        Row(
          children: [
            Expanded(
              child: Container(
                height: 2,
                color: selectedTab == 0 ? Color(0xFF9EF84A) : Colors.transparent,
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: selectedTab == 1 ? Color(0xFF9EF84A) : Colors.transparent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// The rest of your original code remains exactly the same...
class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final DocumentReference orderRef;

  const OrderCard({
    required this.order,
    required this.orderRef,
    Key? key,
  }) : super(key: key);

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
    // Method 1: Check receiverAddress (based on your Firestore structure)
    if (order['receiverAddress'] != null) {
      if (order['receiverAddress'] is Map) {
        final receiver = order['receiverAddress'];
        return receiver['city'] ??
            receiver['fullAddress'] ??
            receiver['street'] ??
            'Unknown Location';
      }
    }

    // Method 2: Fallback to address field (pickup location)
    // Since your Firestore shows 'address' contains the pickup location
    final address = order['address'];
    if (address is Map) {
      return address['city'] ??
          address['fullAddress'] ??
          address['street'] ??
          'Unknown Location';
    }

    return 'Unknown Location';
  }


  String _getCustomerName(Map<String, dynamic> order) {
    return order['customerName'] ??
        order['buyerName'] ??
        'Customer';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'processing':
        return 'PROCESSING';
      case 'shipped':
        return 'SHIPPED';
      case 'completed':
        return 'COMPLETED';
      case 'delivered':
        return 'COMPLETED';
      default:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items[0] : null;

    return GestureDetector(
      onTap: () {
        AppNavigator.navigateToOrderDetails(
          context,
          order: order,
          orderRef: orderRef,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF0B3D3A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF0B7F40),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Order ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['orderId']?.toString().substring(0, 8) ?? 'N/A'}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status'] ?? 'pending'),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(order['status'] ?? 'pending'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Product Info
            if (firstItem != null)
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(firstItem['productImage'] ?? 'https://via.placeholder.com/60'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItem['productName'] ?? 'Product',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Quantity: ${firstItem['quantity']}kg',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'Price: ₦${NumberFormat('#,##0.00').format(firstItem['price'] ?? 0)}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            SizedBox(height: 12),

            // Location Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9EF84A),
                        ),
                      ),
                      Text(
                        _getPickupLocation(order),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'To',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9EF84A),
                        ),
                      ),
                      Text(
                        _getDeliveryLocation(order),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Customer Info
            Text(
              'Customer: ${_getCustomerName(order)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),

            // Order Date
            if (order['createdAt'] != null)
              Text(
                'Order Date: ${DateFormat('dd/MM/yyyy HH:mm').format((order['createdAt'] as Timestamp).toDate())}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
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
            'Manage Orders',
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

// Fixed OrderDetailsPage - StatefulWidget version
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

  void _declineOrder() async {
    try {
      setState(() => isLoading = true);

      await widget.orderRef.update({
        'status': 'pending',
        'driverId': FieldValue.delete(), // Remove driver assignment
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        currentStatus = 'pending';
        showSuccessMessage = true;
      });

      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() => showSuccessMessage = false);
          Navigator.pop(context); // Go back to orders list
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _acceptOrder() async {
    try {
      setState(() => isLoading = true);

      // Get the TrackingProvider
      final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
      final orderId = widget.order['orderId']?.toString() ?? '';

      await widget.orderRef.update({
        'status': 'shipped',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Start tracking for this order
      trackingProvider.startTracking(orderId);

      setState(() {
        currentStatus = 'shipped';
        showSuccessMessage = true;
      });

      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() => showSuccessMessage = false);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  void _navigateToDelivery() {
    final orderId = widget.order['orderId']?.toString() ?? '';
    AppNavigator.navigateToDelivery(
      context,
      orderId: orderId,
    );
  }
  Future<String> _fetchSellerContact(String? sellerId) async {
    if (sellerId == null || sellerId.isEmpty) {
      return 'Not specified';
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>?;
        final phoneNumber = userData?['phone'] ?? userData?['phoneNumber'] ?? userData?['contact'];

        if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
          return phoneNumber.toString();
        }
      }

      return 'Not specified';
    } catch (e) {
      print('Error fetching seller contact: $e');
      return 'Error loading contact';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label on the left
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ),
            SizedBox(width: 16), // Add some spacing between label and value
            // Value on the right with line break capability
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.white,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Divider(color: Color(0xFF0B7F40)),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (currentStatus == 'processing') {
      return Row(
        children: [
          // Decline Button
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : _declineOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                'Decline',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          // Accept Button
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : _acceptOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0B7F40),
                minimumSize: Size(double.infinity, 50),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                'Accept',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (currentStatus == 'shipped') {
      return ElevatedButton(
        onPressed: _navigateToDelivery,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0B7F40),
          minimumSize: Size(double.infinity, 50),
        ),
        child: Text(
          'Track Delivery',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      );
    } else {
      return SizedBox.shrink(); // Hide buttons for other statuses
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final date = (widget.order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

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
                                      "${item['quantity'] as num}${item['unit'] as String}",
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

                    // Order Status Section


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

                          _buildInfoRow('Customer Name', widget.order['customerName'] ?? widget.order['buyerName'] ?? 'Not specified'),
                          _buildInfoRow('Pickup Address', _formatAddress(widget.order['address'])),
                          _buildInfoRow('Delivery Address', _formatAddress(widget.order['receiverAddress'])),
                          _buildInfoRow('Order Date', formattedDate),
                          _buildInfoRow('Total Amount', '₦${_formatPrice(widget.order['totalAmount'] as num? ?? 0)}'),
                        ],
                      ),
                    ),
                    // Replace the entire Seller's Information section with this:

                    SizedBox(height: 16),

// Seller's Information Section
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
                            "Seller's Information",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),

                          // Seller Name
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Seller Name',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Flexible(
                                    child: Text(
                                      widget.order['sellerName'] ?? 'Not specified',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(color: Color(0xFF0B7F40)),
                            ],
                          ),

                          // Seller Contact with FutureBuilder
                          FutureBuilder<String>(
                            future: _fetchSellerContact(widget.order['sellerId']?.toString()),
                            builder: (context, snapshot) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Seller Contact',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Flexible(
                                        child: Builder(
                                          builder: (context) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFF9EF84A),
                                                ),
                                              );
                                            }

                                            if (snapshot.hasError) {
                                              return Text(
                                                'Error loading',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 16,
                                                  color: Colors.red,
                                                ),
                                                textAlign: TextAlign.right,
                                              );
                                            }

                                            final contact = snapshot.data ?? 'Not specified';
                                            return Text(
                                              contact,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.visible,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Divider(color: Color(0xFF0B7F40)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Action Buttons Section
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
                            'Order Actions',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildActionButtons(),
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
    );
  }
}
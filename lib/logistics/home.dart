import 'package:bayangida_logistics/profile/deliveryaddress.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_navigator.dart';
import '../bottom_nav_bar.dart';
import '../providers/user_provider.dart';
import 'notificationstatus.dart';

class WelcomeDashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    final userId = user.uid;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: Color(0xFF042E22),
      body: Column(
        children: [
          // Fixed header section
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.03,
            ),
            color: Color(0xFF042E22),
            child: Header(),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OrderStatsGrid(userId: userId),
                  SizedBox(height: screenHeight * 0.03),
                  ActiveDeliverySection(userId: userId),
                  SizedBox(height: screenHeight * 0.03),
                  AddVehicleButton(),
                  SizedBox(height: screenHeight * 0.03),
                  EarningsSection(userId: userId),
                  SizedBox(height: screenHeight * 0.03),
                  FleetSection(userId: userId),
                  SizedBox(height: screenHeight * 0.1), // Space for bottom nav
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.02,
        ),
        child: BottomNavigationBarComponent(currentIndex: 0),
      ),
    );
  }
}

class Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    final firstName = user.displayName ?? '';
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome${firstName.isNotEmpty ? ', $firstName' : ''}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: screenWidth * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                'We are glad to have you back.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: screenWidth * 0.035,
                  color: Color(0xFF9EF84A),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationsPage()),
            );
          },
          child: Icon(
            Icons.notifications,
            color: Color(0xFF9EF84A),
            size: screenWidth * 0.07,
          ),
        ),
      ],
    );
  }
}

class OrderStatsGrid extends StatelessWidget {
  final String? userId;

  const OrderStatsGrid({required this.userId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingStats(screenWidth);
        }

        final orders = snapshot.data!.docs;

        // Calculate order counts based on status
        int totalOrders = orders.length;
        int completedOrders = orders.where((doc) {
          final order = doc.data() as Map<String, dynamic>;
          return order['status'] == 'completed' || order['status'] == 'delivered';
        }).length;

        int pendingOrders = orders.where((doc) {
          final order = doc.data() as Map<String, dynamic>;
          return order['status'] == 'processing' || order['status'] == 'shipped';
        }).length;

        int cancelledOrders = orders.where((doc) {
          final order = doc.data() as Map<String, dynamic>;
          return order['status'] == 'cancelled';
        }).length;

        return GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: screenWidth * 0.04,
          mainAxisSpacing: screenWidth * 0.04,
          childAspectRatio: 1.8,
          children: [
            StatCard(
              title: 'Total Orders',
              value: '$totalOrders',
              icon: Icons.list_alt,
              screenWidth: screenWidth,
            ),
            StatCard(
              title: 'Completed orders',
              value: '$completedOrders',
              icon: Icons.check_circle,
              screenWidth: screenWidth,
            ),
            StatCard(
              title: 'Pending orders',
              value: '$pendingOrders',
              icon: Icons.pending,
              screenWidth: screenWidth,
            ),
            StatCard(
              title: 'Cancelled orders',
              value: '$cancelledOrders',
              icon: Icons.cancel,
              screenWidth: screenWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingStats(double screenWidth) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: screenWidth * 0.04,
      mainAxisSpacing: screenWidth * 0.04,
      childAspectRatio: 1.8,
      children: [
        StatCard(
          title: 'Total Orders',
          value: '0',
          icon: Icons.list_alt,
          screenWidth: screenWidth,
        ),
        StatCard(
          title: 'Completed orders',
          value: '0',
          icon: Icons.check_circle,
          screenWidth: screenWidth,
        ),
        StatCard(
          title: 'Pending orders',
          value: '0',
          icon: Icons.pending,
          screenWidth: screenWidth,
        ),
        StatCard(
          title: 'Cancelled orders',
          value: '0',
          icon: Icons.cancel,
          screenWidth: screenWidth,
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double screenWidth;

  const StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(
          color: Color(0xFF0B7F40),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFF9EF84A), size: screenWidth * 0.05),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: screenWidth * 0.035,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenWidth * 0.015),
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActiveDeliverySection extends StatelessWidget {
  final String? userId;

  const ActiveDeliverySection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: userId)
          .where('status', whereIn: ['processing', 'shipped'])
          .orderBy('assignedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoActiveDeliveries(screenWidth, screenHeight);
        }

        final orderDoc = snapshot.data!.docs.first;
        final order = orderDoc.data() as Map<String, dynamic>;

        return GestureDetector(
          onTap: () => AppNavigator.navigateToOrderDetails(
            context,
            order: order,
            orderRef: orderDoc.reference,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Delivery',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(
                    color: Color(0xFF0B7F40),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tracking Number',
                                style: TextStyle(
                                  color: Color(0xFF9EF84A),
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                              Text(
                                '#${order['orderId']?.toString().substring(0, 8) ?? orderDoc.id.substring(0, 8)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'From',
                                style: TextStyle(
                                  color: Color(0xFF9EF84A),
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                              Text(
                                _getPickupLocation(order),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Divider(
                      color: Color(0xFF9EF84A).withOpacity(0.3),
                      thickness: 1,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer',
                                style: TextStyle(
                                  color: Color(0xFF9EF84A),
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                              Text(
                                _getCustomerName(order),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'To',
                                style: TextStyle(
                                  color: Color(0xFF9EF84A),
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                              Text(
                                _getDeliveryLocation(order),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Divider(
                      color: Color(0xFF9EF84A).withOpacity(0.3),
                      thickness: 1,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status',
                                style: TextStyle(
                                  color: Color(0xFF9EF84A),
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.03,
                                  vertical: screenHeight * 0.005,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFF9EF84A),
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                ),
                                child: Text(
                                  (order['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Arrival Date',
                                style: TextStyle(
                                  color: Color(0xFF9EF84A),
                                  fontSize: screenWidth * 0.035,
                                ),
                              ),
                              Text(
                                _formatDate(order['estimatedDeliveryDate']),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPickupLocation(Map<String, dynamic> order) {
    // Method 1: Check if pickupLocation exists and has address data
    if (order['pickupLocation'] != null) {
      if (order['pickupLocation'] is Map) {
        final pickup = order['pickupLocation'];
        return pickup['city'] ??
            pickup['fullAddress'] ??
            pickup['street'] ??
            'Unknown Location';
      }
    }

    // Method 2: Fallback to seller's address structure
    final address = order['address'];
    if (address is Map) {
      return address['city'] ??
          address['fullAddress'] ??
          address['street'] ??
          'Unknown Location';
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
    // Based on farmer's code structure
    return order['customerName'] ??
        order['buyerName'] ??
        'Customer';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      return DateFormat('dd-MM-yyyy').format(date.toDate());
    }
    return 'N/A';
  }

  Widget _buildNoActiveDeliveries(double screenWidth, double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Delivery',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            border: Border.all(
              color: Color(0xFF0B7F40),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              'No active deliveries',
              style: TextStyle(
                color: Colors.white70,
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AddVehicleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FleetManagementPage()),
          );
        },
        icon: Icon(Icons.add, color: Colors.white, size: screenWidth * 0.06),
        label: Text(
          'Add new vehicle details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: screenWidth * 0.04,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0B7F40),
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.1),
          ),
        ),
      ),
    );
  }
}

class EarningsSection extends StatelessWidget {
  final String? userId;

  const EarningsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingEarnings(screenWidth, screenHeight);
        }

        final orders = snapshot.data!.docs;

        // Calculate earnings and order counts from actual orders
        double totalEarnings = 0;
        double monthlyEarnings = 0;
        double availableEarnings = 0;
        int activeOrders = 0;
        int cancelledOrders = 0;
        int completedOrders = 0;

        final currentMonth = DateTime.now().month;
        final currentYear = DateTime.now().year;

        for (var doc in orders) {
          final order = doc.data() as Map<String, dynamic>;
          final status = order['status']?.toString() ?? '';
          final createdAt = order['createdAt'] as Timestamp?;
          final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0;

          // Calculate driver earnings (total amount minus product costs)
          double productCost = 0;
          final items = order['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
              productCost += price * quantity;
            }
          }

          final driverEarnings = totalAmount - productCost;

          // Update counts and earnings based on status
          if (status == 'processing' || status == 'shipped' || status == 'delivered') {
            activeOrders++;
          } else if (status == 'cancelled') {
            cancelledOrders++;
          } else if (status == 'completed' ) {
            completedOrders++;
            totalEarnings += driverEarnings;
            availableEarnings += driverEarnings;

            // Check if order is from current month for monthly earnings
            if (createdAt != null) {
              final orderDate = createdAt.toDate();
              if (orderDate.month == currentMonth && orderDate.year == currentYear) {
                monthlyEarnings += driverEarnings;
              }
            }
          }
        }

        return Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            border: Border.all(
              color: Color(0xFF0B7F40),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earnings/orders',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Earnings in ${DateFormat('MMMM').format(DateTime.now())}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        Text(
                          'N${NumberFormat('#,##0').format(monthlyEarnings)}',
                          style: TextStyle(
                            color: Color(0xFF9EF84A),
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Active orders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        Text(
                          '$activeOrders',
                          style: TextStyle(
                            color: Color(0xFF9EF84A),
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Earnings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        Text(
                          'N${NumberFormat('#,##0').format(totalEarnings)}',
                          style: TextStyle(
                            color: Color(0xFF9EF84A),
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Cancelled orders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        Text(
                          '$cancelledOrders',
                          style: TextStyle(
                            color: Color(0xFF9EF84A),
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available for withdrawal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        Text(
                          'N${NumberFormat('#,##0').format(availableEarnings)}',
                          style: TextStyle(
                            color: Color(0xFF9EF84A),
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Completed orders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        Text(
                          '$completedOrders',
                          style: TextStyle(
                            color: Color(0xFF9EF84A),
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingEarnings(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(
          color: Color(0xFF0B7F40),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings/orders',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Earnings in ${DateFormat('MMMM').format(DateTime.now())}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                    Text(
                      'N0',
                      style: TextStyle(
                        color: Color(0xFF9EF84A),
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Active orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                    Text(
                      '0',
                      style: TextStyle(
                        color: Color(0xFF9EF84A),
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FleetSection extends StatelessWidget {
  final String? userId;

  const FleetSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (userId == null) {
      return _buildNoFleetMessage(context, 'User not authenticated', screenWidth, screenHeight);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fleet')
          .orderBy('isDefault', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingFleet(screenWidth, screenHeight);
        }

        if (snapshot.hasError) {
          return _buildNoFleetMessage(context, 'Error loading fleet data', screenWidth, screenHeight);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoFleetMessage(context, 'No vehicles added yet', screenWidth, screenHeight);
        }

        final fleetDocs = snapshot.data!.docs;

        return Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            border: Border.all(
              color: Color(0xFF0B7F40),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fleet',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: screenWidth * 0.06),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FleetManagementPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              ...fleetDocs.map((doc) {
                final vehicle = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle['vehicleType'] ?? 'Vehicle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.035,
                                  ),
                                ),
                                Text(
                                  vehicle['plateNumber'] ?? 'N/A',
                                  style: TextStyle(
                                    color: Color(0xFF9EF84A),
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.02,
                                    vertical: screenHeight * 0.005,
                                  ),
                                  decoration: BoxDecoration(
                                    color: vehicle['isDefault'] == true
                                        ? Color(0xFF0B7F40).withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(screenWidth * 0.01),
                                    border: Border.all(
                                      color: vehicle['isDefault'] == true
                                          ? Color(0xFF0B7F40)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    vehicle['isDefault'] == true
                                        ? 'DEFAULT'
                                        : 'AVAILABLE',
                                    style: TextStyle(
                                      color: vehicle['isDefault'] == true
                                          ? Color(0xFF9EF84A)
                                          : Colors.white,
                                      fontSize: screenWidth * 0.03,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                Text(
                                  '${vehicle['model'] ?? ''} • ${vehicle['colour'] ?? ''}',
                                  style: TextStyle(
                                    color: Color(0xFF9EF84A),
                                    fontSize: screenWidth * 0.035,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        'Driver: ${vehicle['name'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth * 0.035,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        'License: ${vehicle['license'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth * 0.035,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingFleet(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(
          color: Color(0xFF0B7F40),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Center(
            child: CircularProgressIndicator(
              color: Color(0xFF9EF84A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFleetMessage(BuildContext context, String message, double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(
          color: Color(0xFF0B7F40),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Center(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white70,
                fontSize: screenWidth * 0.04,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FleetManagementPage(),
                  ),
                );
              },
              child: Text(
                'Add Vehicle',
                style: TextStyle(
                  color: Color(0xFF9EF84A),
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
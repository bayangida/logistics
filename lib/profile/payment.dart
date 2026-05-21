import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../logistics/notificationstatus.dart';

class EarningsPage extends StatefulWidget {
  @override
  _EarningsPageState createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? earningsData;
  bool _isLoading = true;
  bool _hasMadeWithdrawal = false;
  bool _isCheckingWithdrawal = true;

  @override
  void initState() {
    super.initState();
    _checkIfWithdrawalMade();
    _fetchEarningsData();
  }

  Future<void> _checkIfWithdrawalMade() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final withdrawalsSnapshot = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        _hasMadeWithdrawal = withdrawalsSnapshot.docs.isNotEmpty;
        _isCheckingWithdrawal = false;
      });
    } catch (e) {
      print('Error checking withdrawals: $e');
      setState(() {
        _isCheckingWithdrawal = false;
      });
    }
  }

  Future<void> _fetchEarningsData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get all orders for this driver
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: userId)
          .get();

      double totalEarnings = 0;
      double monthlyEarnings = 0;
      double availableEarnings = 0;

      final currentMonth = DateTime.now().month;
      final currentYear = DateTime.now().year;

      for (var doc in ordersSnapshot.docs) {
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

        // Only count completed/delivered orders for earnings
        if (status == 'completed') {
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

      setState(() {
        earningsData = {
          'monthly': monthlyEarnings,
          'total': totalEarnings,
          'available': availableEarnings,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        earningsData = _getDefaultEarnings();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDefaultEarnings() {
    return {
      'monthly': 0,
      'total': 0,
      'available': 0,
    };
  }

  String _formatNumber(dynamic number) {
    if (number is int || number is double) {
      return number.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},');
    }
    return '0';
  }

  Future<void> _showWithdrawalWarning() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdrawal Limit Reached'),
        content: Text(
          'You can only make one withdrawal request per account. '
              'You have already made a withdrawal request and cannot make another one.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF0B7F40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawalConfirmation() async {
    final available = earningsData?['available'] ?? 0;

    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No funds available for withdrawal')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to withdraw N${_formatNumber(available)}?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '⚠️ Important:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You can only make ONE withdrawal request per account. '
                  'This action cannot be undone and you will not be able to make another withdrawal request in the future.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _submitWithdrawalRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0B7F40),
            ),
            child: Text(
              'Confirm',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitWithdrawalRequest() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final available = earningsData?['available'] ?? 0;

      if (available <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No funds available for withdrawal')),
        );
        return;
      }

      // Double check if user has already made a withdrawal
      final existingWithdrawals = await _firestore
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .get();

      if (existingWithdrawals.docs.isNotEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have already made a withdrawal request'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save withdrawal request
      await _firestore.collection('withdrawals').add({
        'userId': userId,
        'amount': available,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isFirstAndOnlyWithdrawal': true, // Mark as the only withdrawal
      });

      // Update local state
      setState(() {
        _hasMadeWithdrawal = true;
      });

      // Refresh data
      await _fetchEarningsData();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit withdrawal request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildWithdrawalButton() {
    if (_isCheckingWithdrawal) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    if (_hasMadeWithdrawal) {
      return ElevatedButton(
        onPressed: _showWithdrawalWarning,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          'Withdrawal Made',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      );
    }

    final available = earningsData?['available'] ?? 0;
    return ElevatedButton(
      onPressed: available > 0 ? _showWithdrawalConfirmation : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: available > 0 ? Color(0xFF042E22) : Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(
        'Withdraw',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthly = earningsData?['monthly'] ?? 0;
    final total = earningsData?['total'] ?? 0;
    final available = earningsData?['available'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF0B7F40)))
                : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Withdrawal Warning Banner
                  if (_hasMadeWithdrawal)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Withdrawal Limit Reached',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'You have already made your one-time withdrawal request. '
                                      'No further withdrawals are allowed.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Total Balance Card
                  Container(
                    width: double.infinity,
                    height: 170,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF0B7F40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Balance',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Color(0xFF9EF84A),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color(0xFF9EF84A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.yellow, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '4.8',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'N${_formatNumber(total)}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available for withdrawal',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                    color: Color(0xFF9EF84A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'N${_formatNumber(available)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            _buildWithdrawalButton(),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Monthly Earnings Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF042E22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Earnings',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF9EF84A),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'N${_formatNumber(monthly)}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Earnings for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Transactions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'View all',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Color(0xFF0B7F40),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Transaction Cards
                  _buildTransactionsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('driverId', isEqualTo: _auth.currentUser?.uid)
          .where('status', whereIn: ['completed', 'delivered'])
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF0B7F40)));
        }

        final orders = snapshot.data!.docs;

        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No completed transactions yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        return Column(
          children: orders.map((doc) {
            final order = doc.data() as Map<String, dynamic>;
            final items = order['items'] as List<dynamic>? ?? [];
            final firstItem = items.isNotEmpty ? items[0] : null;

            // Calculate driver earnings
            double productCost = 0;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
                productCost += price * quantity;
              }
            }
            final driverEarnings = (order['totalAmount'] as num?)?.toDouble() ?? 0 - productCost;

            return TransactionCard(
              productName: firstItem?['productName'] ?? 'Delivery',
              date: DateFormat('MMM dd, yyyy').format(
                  (order['createdAt'] as Timestamp).toDate()),
              amount: driverEarnings.toStringAsFixed(2),
              orderId: order['orderId']?.toString() ?? doc.id,
            );
          }).toList(),
        );
      },
    );
  }
}

class TransactionCard extends StatelessWidget {
  final String productName;
  final String date;
  final String amount;
  final String orderId;

  const TransactionCard({
    required this.productName,
    required this.date,
    required this.amount,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Order #${orderId.substring(0, 8)}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+NGN ${NumberFormat('#,##0.00').format(double.parse(amount))}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF24A731),
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
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Centered title
          Padding(
            padding: const EdgeInsets.only(top: 60.0, bottom: 28),
            child: Center(
              child: Text(
                'Payment',
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
            padding: const EdgeInsets.only(top: 60.0, bottom: 28, right: 9),
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
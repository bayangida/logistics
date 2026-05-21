import 'package:bayangida_logistics/profile/payment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bottom_nav_bar.dart';
import '../login/login.dart';
import '../logistics/notificationstatus.dart';
import '../providers/user_provider.dart';
import 'about.dart';
import 'deliveryaddress.dart';
import 'editdetails.dart' hide BottomNavigationBarComponent;
import 'history.dart' hide BottomNavigationBarComponent;
import 'language.dart' hide BottomNavigationBarComponent;
import 'notification.dart' hide BottomNavigationBarComponent;

// Add this import for FleetManagementPage (adjust path as needed)
// import 'fleet_management.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.displayName ?? 'User';
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive scaling factors
    final scaleFactorWidth = screenWidth / 375;
    final scaleFactorHeight = screenHeight / 812;

    double responsiveWidth(double size) => size * scaleFactorWidth;
    double responsiveHeight(double size) => size * scaleFactorHeight;
    double responsiveFont(double size) => size * scaleFactorWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(
            responsiveHeight: responsiveHeight,
            responsiveWidth: responsiveWidth,
            responsiveFont: responsiveFont,
          ),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  children: [
                    ProfileListItem(
                      title: 'Personal Details',
                      icon: Icons.person_outline,
                      destinationPage: personaledit(),
                      responsiveHeight: responsiveHeight,
                      responsiveWidth: responsiveWidth,
                      responsiveFont: responsiveFont,
                    ),
                    ProfileListItem(
                      title: 'Fleet',
                      icon: Icons.location_on_outlined,
                      destinationPage: FleetManagementPage(), // Make sure this import exists
                      responsiveHeight: responsiveHeight,
                      responsiveWidth: responsiveWidth,
                      responsiveFont: responsiveFont,
                    ),
                    ProfileListItem(
                      title: 'Notification preferences',
                      icon: Icons.notifications_none,
                      destinationPage: NotificationPreferencesPage(),
                      responsiveHeight: responsiveHeight,
                      responsiveWidth: responsiveWidth,
                      responsiveFont: responsiveFont,
                    ),
                    ProfileListItem(
                      title: 'Order history',
                      icon: Icons.history,
                      destinationPage: HistoryPage(),
                      responsiveHeight: responsiveHeight,
                      responsiveWidth: responsiveWidth,
                      responsiveFont: responsiveFont,
                    ),
                    ProfileListItem(
                      title: 'Earnings',
                      icon: Icons.info_outline,
                      destinationPage: EarningsPage(),
                      responsiveHeight: responsiveHeight,
                      responsiveWidth: responsiveWidth,
                      responsiveFont: responsiveFont,
                    ),
                    ProfileListItem(
                      title: 'About Bayangida',
                      icon: Icons.info_outline,
                      destinationPage: AboutPage(),
                      responsiveHeight: responsiveHeight,
                      responsiveWidth: responsiveWidth,
                      responsiveFont: responsiveFont,
                    ),

                    // Account Deletion Section
                    SizedBox(height: responsiveHeight(20)),
                    _buildAccountDeletionSection(
                      context,
                      responsiveHeight,
                      responsiveWidth,
                      responsiveFont,
                    ),

                    SizedBox(height: responsiveHeight(100)),
                  ],
                ),

                Positioned(
                  bottom: responsiveHeight(150),
                  left: responsiveWidth(16),
                  right: responsiveWidth(16),
                  child: FloatingButtons(
                    responsiveHeight: responsiveHeight,
                    responsiveWidth: responsiveWidth,
                    responsiveFont: responsiveFont,
                  ),
                ),

                Positioned(
                  left: responsiveWidth(20),
                  bottom: responsiveHeight(20),
                  right: responsiveWidth(20),
                  child: BottomNavigationBarComponent(currentIndex: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDeletionSection(
      BuildContext context,
      Function(double) responsiveHeight,
      Function(double) responsiveWidth,
      Function(double) responsiveFont,
      ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsiveWidth(16)),
      padding: EdgeInsets.all(responsiveWidth(4)),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(responsiveWidth(12)),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permanently delete your account',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: responsiveFont(12),
              color: Colors.red.withOpacity(0.7),
            ),
          ),
          SizedBox(height: responsiveHeight(5)),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(responsiveWidth(8)),
            ),
            child: TextButton(
              onPressed: () => _showDeleteAccountDialog(
                context,
                responsiveHeight,
                responsiveWidth,
                responsiveFont,
              ),
              child: Text(
                'Delete Account',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: responsiveFont(14),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(
      BuildContext context,
      Function(double) responsiveHeight,
      Function(double) responsiveWidth,
      Function(double) responsiveFont,
      ) async {
    await showDialog(
      context: context,
      builder: (context) => DeleteAccountDialog(
        responsiveHeight: responsiveHeight,
        responsiveWidth: responsiveWidth,
        responsiveFont: responsiveFont,
      ),
    );
  }
}

class DeleteAccountDialog extends StatefulWidget {
  final Function(double) responsiveHeight;
  final Function(double) responsiveWidth;
  final Function(double) responsiveFont;

  const DeleteAccountDialog({
    Key? key,
    required this.responsiveHeight,
    required this.responsiveWidth,
    required this.responsiveFont,
  }) : super(key: key);

  @override
  _DeleteAccountDialogState createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _confirmationController = TextEditingController();
  bool _isDeleting = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(widget.responsiveWidth(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                SizedBox(width: widget.responsiveWidth(8)),
                Text(
                  'Delete Account',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: widget.responsiveFont(18),
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            SizedBox(height: widget.responsiveHeight(16)),

            // Warning message
            Text(
              'This action is permanent and cannot be undone. All your data will be deleted including:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: widget.responsiveFont(14),
                color: Colors.grey[700],
              ),
            ),

            SizedBox(height: widget.responsiveHeight(12)),

            // Warning items
            _buildWarningItem('Personal information'),
            _buildWarningItem('Order history'),
            _buildWarningItem('Earnings data'),
            _buildWarningItem('Fleet information'),
            _buildWarningItem('Notification preferences'),

            SizedBox(height: widget.responsiveHeight(16)),

            // Confirmation input
            TextField(
              controller: _confirmationController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type "DELETE" to confirm',
                hintText: 'DELETE',
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) => setState(() {}),
            ),

            SizedBox(height: widget.responsiveHeight(12)),

            // Terms checkbox
            Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                ),
                Expanded(
                  child: Text(
                    'I understand this action cannot be undone',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: widget.responsiveFont(12),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: widget.responsiveHeight(16)),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isDeleting ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: widget.responsiveFont(14)),
                    ),
                  ),
                ),
                SizedBox(width: widget.responsiveWidth(8)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canDelete() && !_isDeleting ? () => _deleteAccount(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.red.withOpacity(0.5),
                    ),
                    child: _isDeleting
                        ? SizedBox(
                      width: widget.responsiveWidth(20),
                      height: widget.responsiveWidth(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: widget.responsiveFont(14),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.responsiveHeight(4)),
      child: Row(
        children: [
          Icon(Icons.remove, size: 16, color: Colors.red),
          SizedBox(width: widget.responsiveWidth(8)),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: widget.responsiveFont(12),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  bool _canDelete() {
    return _confirmationController.text.trim().toUpperCase() == 'DELETE' &&
        _termsAccepted;
  }

  Future<void> _deleteAccount(BuildContext context) async {
    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Delete user data from Firestore first
      await _deleteUserData(user.uid);

      // Delete the user account from Firebase Auth
      await user.delete();

      // Clear local state
      await userProvider.logout();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => FarmerLoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);

        // Handle specific errors
        String errorMessage = _getErrorMessage(e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'requires-recent-login':
          return 'Please re-authenticate before deleting your account for security reasons.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'user-not-found':
          return 'User account not found.';
        case 'invalid-user-token':
          return 'Session expired. Please login again.';
        default:
          return 'Account deletion failed: ${e.message}';
      }
    }
    return 'Account deletion failed: ${e.toString()}';
  }

  Future<void> _deleteUserData(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(userId);

    try {
      // Delete subcollections first (in correct order)
      await _deleteSubcollection(userRef, 'earnings');
      await _deleteSubcollection(userRef, 'fleet');
      await _deleteSubcollection(userRef, 'preferences');

      // Then delete the main user document
      await userRef.delete();

      print('User data deleted successfully for UID: $userId');
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }

  Future<void> _deleteSubcollection(DocumentReference userRef, String collectionName) async {
    try {
      final collectionRef = userRef.collection(collectionName);
      final snapshot = await collectionRef.get();

      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print('Deleted $collectionName subcollection for user');
      }
    } catch (e) {
      print('Error deleting $collectionName subcollection: $e');
      // Continue with deletion even if subcollection deletion fails
    }
  }
}

// ... Rest of your existing HeaderComponent, ProfileListItem, and FloatingButtons classes remain the same
// ... Keep your existing HeaderComponent, ProfileListItem, and FloatingButtons classes unchanged


class HeaderComponent extends StatelessWidget {
  final Function(double) responsiveHeight;
  final Function(double) responsiveWidth;
  final Function(double) responsiveFont;

  const HeaderComponent({
    Key? key,
    required this.responsiveHeight,
    required this.responsiveWidth,
    required this.responsiveFont,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF042E22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back button aligned to the left
          Padding(
            padding: EdgeInsets.only(
              top: responsiveHeight(60.0),
              bottom: responsiveHeight(28),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.all(responsiveWidth(8.0)),
                decoration: BoxDecoration(
                  color: Color(0xFFFF0B7F40),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Color(0xFF9EF84A),
                    size: responsiveFont(24),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Centered title
          Padding(
            padding: EdgeInsets.only(
              top: responsiveHeight(60.0),
              bottom: responsiveHeight(28),
            ),
            child: Center(
              child: Text(
                'Profile',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: responsiveFont(20),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Notification icon aligned to the right
          Padding(
            padding: EdgeInsets.only(
              top: responsiveHeight(60.0),
              bottom: responsiveHeight(28),
                right :9
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
                  size: responsiveFont(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileListItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget destinationPage;
  final Function(double) responsiveHeight;
  final Function(double) responsiveWidth;
  final Function(double) responsiveFont;

  const ProfileListItem({
    required this.title,
    required this.icon,
    required this.destinationPage,
    required this.responsiveHeight,
    required this.responsiveWidth,
    required this.responsiveFont,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationPage),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsiveWidth(16),
          vertical: responsiveHeight(12),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Color(0xFF1E293B),
              size: responsiveFont(24),
            ),
            SizedBox(width: responsiveWidth(12)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: responsiveFont(16),
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF1E293B),
              size: responsiveFont(16),
            ),
          ],
        ),
      ),
    );
  }
}

class FloatingButtons extends StatelessWidget {
  final Function(double) responsiveHeight;
  final Function(double) responsiveWidth;
  final Function(double) responsiveFont;

  const FloatingButtons({
    Key? key,
    required this.responsiveHeight,
    required this.responsiveWidth,
    required this.responsiveFont,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsiveWidth(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLogoutButton(context),
          _buildMessageButton(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF0B7F40),
        borderRadius: BorderRadius.circular(responsiveWidth(20)),
      ),
      child: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          return TextButton.icon(
            onPressed: userProvider.isLoading
                ? null
                : () => _showLogoutConfirmation(context, userProvider),
            icon: Icon(
              Icons.logout,
              color: Color(0xFF9EF84A),
              size: responsiveFont(20),
            ),
            label: Text(
              'Log out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: responsiveFont(14),
                fontWeight: FontWeight.w500,
                color: Color(0xFF9EF84A),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageButton() {
    return Container(
      width: responsiveWidth(56),
      height: responsiveHeight(56),
      decoration: BoxDecoration(
        color: Color(0xFF0B7F40),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () {
          // Handle message button press
        },
        icon: Icon(
          Icons.message,
          color: Color(0xFF9EF84A),
          size: responsiveFont(24),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(
      BuildContext context, UserProvider userProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: TextStyle(fontSize: responsiveFont(18)),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: responsiveFont(16)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: responsiveFont(16)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: TextStyle(
                color: Colors.red,
                fontSize: responsiveFont(16),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performLogout(context, userProvider);
    }
  }

  Future<void> _performLogout(
      BuildContext context, UserProvider userProvider) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      await userProvider.logout();

      // Close loading indicator
      Navigator.pop(context);

      // Navigate to login screen and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => FarmerLoginPage()),
            (route) => false,
      );
    } catch (e) {
      // Close loading indicator
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
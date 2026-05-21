import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../bottom_nav_bar.dart';
import '../app_navigator.dart';
import 'notificationstatus.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderId;
  final String currentStep;
  final VoidCallback onStepCompleted;

  const DeliveryTrackingPage({
    Key? key,
    required this.orderId,
    required this.currentStep,
    required this.onStepCompleted,
  }) : super(key: key);

  @override
  _DeliveryTrackingPageState createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  late GoogleMapController mapController;
  LatLng? currentPosition;
  LatLng? farmerPosition;
  LatLng? receiverPosition;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool isLoading = true;
  bool showSuccessPopup = false;
  Timer? locationUpdateTimer;
  Timer? routeUpdateTimer;
  double deliveryProgress = 0.0;
  String estimatedTime = 'Calculating...';
  double totalDistance = 0.0;
  bool hasArrived = false;
  bool showChatDialog = false;
  final TextEditingController _messageController = TextEditingController();
  List<String> chatMessages = [
    "Hello! I'm on my way for the pickup.",
    "I'll be there in about 10 minutes.",
    "I've arrived at the location."
  ];

  @override
  void initState() {
    super.initState();
    _initializeDeliveryData();
  }

  @override
  void dispose() {
    locationUpdateTimer?.cancel();
    routeUpdateTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeDeliveryData() async {
    try {
      // Fetch order details
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final order = orderDoc.data() as Map<String, dynamic>;

      // Get farmer address
      final farmerAddressDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(order['sellerId'])
          .collection('addresses')
          .limit(1)
          .get();

      if (farmerAddressDoc.docs.isEmpty) {
        throw Exception('Farmer address not found');
      }

      final farmerAddress = farmerAddressDoc.docs.first.data();

      // Handle receiver address - check if it's a string or map
      String receiverAddressString;
      final receiverAddress = order['address'];

      if (receiverAddress is String) {
        receiverAddressString = receiverAddress;
      } else if (receiverAddress is Map<String, dynamic>) {
        // Construct address string from address map
        receiverAddressString = _constructAddressString(receiverAddress);
      } else {
        throw Exception('Invalid address format');
      }

      // Construct farmer address string
      final farmerAddressString = _constructAddressString(farmerAddress);

      // Geocode addresses to get coordinates
      final farmerLocation = await _geocodeAddress(farmerAddressString);
      final receiverLocation = await _geocodeAddress(receiverAddressString);

      setState(() {
        farmerPosition = farmerLocation;
        receiverPosition = receiverLocation;
      });

      // Calculate total distance
      totalDistance = Geolocator.distanceBetween(
        farmerPosition!.latitude,
        farmerPosition!.longitude,
        receiverPosition!.latitude,
        receiverPosition!.longitude,
      );

      // Start tracking
      _startLocationUpdates();
      _updateRoute();
    } catch (e) {
      print('Error initializing delivery data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading delivery data: $e')),
      );
    }
  }

  // Helper method to construct address string from map
  String _constructAddressString(Map<String, dynamic> addressMap) {
    final parts = [
      addressMap['address'],
      addressMap['city'],
      addressMap['state'],
      addressMap['country'],
    ].where((part) => part != null && part.isNotEmpty).toList();

    return parts.join(', ');
  }

  Future<LatLng> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) {
        throw Exception('Could not geocode address: $address');
      }
      return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (e) {
      print('Geocoding error: $e');
      rethrow;
    }
  }

  void _startLocationUpdates() {
    // Get initial position
    _getCurrentLocation();

    // Update position every 10 seconds
    locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _getCurrentLocation();
    });
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
          throw Exception('Location permissions are denied');
        }
      }

      // Only use foreground location
      if (permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        setState(() {
          currentPosition = LatLng(position.latitude, position.longitude);
          isLoading = false;
        });

        _checkArrivalStatus();
        _updateMarkers();
        _moveCameraToRoute();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _checkArrivalStatus() {
    if (currentPosition == null ||
        (widget.currentStep == 'arrived' && farmerPosition == null) ||
        (widget.currentStep == 'pickup' && receiverPosition == null)) return;

    double thresholdDistance = 50; // 50 meters threshold for arrival
    double distanceToTarget = 0;

    if (widget.currentStep == 'arrived' && farmerPosition != null) {
      distanceToTarget = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        farmerPosition!.latitude,
        farmerPosition!.longitude,
      );
    } else if (widget.currentStep == 'pickup' && receiverPosition != null) {
      distanceToTarget = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        receiverPosition!.latitude,
        receiverPosition!.longitude,
      );
    }

    if (distanceToTarget <= thresholdDistance && !hasArrived) {
      setState(() {
        hasArrived = true;
      });
    }
  }

  void _updateRoute() {
    // Update route every 30 seconds
    routeUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (currentPosition == null ||
          farmerPosition == null ||
          receiverPosition == null) return;

      // Calculate delivery progress
      double currentDistance = 0;

      if (widget.currentStep == 'arrived') {
        // Distance from current position to farmer position
        currentDistance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          farmerPosition!.latitude,
          farmerPosition!.longitude,
        );
      } else if (widget.currentStep == 'pickup') {
        // Distance from current position to receiver position
        currentDistance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          receiverPosition!.latitude,
          receiverPosition!.longitude,
        );
      }

      setState(() {
        deliveryProgress =
            (1 - (currentDistance / totalDistance)).clamp(0.0, 1.0);

        // Estimate time remaining based on average walking speed (1.4 m/s)
        final secondsRemaining = currentDistance / 1.4;
        if (secondsRemaining < 60) {
          estimatedTime = 'Less than 1 min';
        } else {
          estimatedTime = '${(secondsRemaining / 60).round()} min';
        }
      });

      _updateMarkers();
      _updatePolylines();
    });
  }

  void _updateMarkers() {
    if (currentPosition == null ||
        farmerPosition == null ||
        receiverPosition == null) return;

    setState(() {
      markers = {
        Marker(
          markerId: MarkerId('current_position'),
          position: currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
        if (widget.currentStep == 'arrived')
          Marker(
            markerId: MarkerId('farmer_position'),
            position: farmerPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(title: 'Pickup Location'),
          ),
        if (widget.currentStep == 'pickup')
          Marker(
            markerId: MarkerId('receiver_position'),
            position: receiverPosition!,
            icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Delivery Location'),
          ),
      };
    });
  }

  void _updatePolylines() {
    if (currentPosition == null ||
        farmerPosition == null ||
        receiverPosition == null) return;

    setState(() {
      polylines = {
        if (widget.currentStep == 'arrived')
          Polyline(
            polylineId: PolylineId('to_farmer'),
            points: [currentPosition!, farmerPosition!],
            color: Colors.blue,
            width: 4,
            geodesic: true,
          ),
        if (widget.currentStep == 'pickup')
          Polyline(
            polylineId: PolylineId('to_receiver'),
            points: [currentPosition!, receiverPosition!],
            color: Colors.red,
            width: 4,
            geodesic: true,
          ),
      };
    });
  }

  void _moveCameraToRoute() {
    if (currentPosition == null ||
        farmerPosition == null ||
        receiverPosition == null) return;

    LatLngBounds bounds;

    if (widget.currentStep == 'arrived') {
      bounds = LatLngBounds(
        southwest: LatLng(
          min(farmerPosition!.latitude, currentPosition!.latitude),
          min(farmerPosition!.longitude, currentPosition!.longitude),
        ),
        northeast: LatLng(
          max(farmerPosition!.latitude, currentPosition!.latitude),
          max(farmerPosition!.longitude, currentPosition!.longitude),
        ),
      );
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(
          min(receiverPosition!.latitude, currentPosition!.latitude),
          min(receiverPosition!.longitude, currentPosition!.longitude),
        ),
        northeast: LatLng(
          max(receiverPosition!.latitude, currentPosition!.latitude),
          max(receiverPosition!.longitude, currentPosition!.longitude),
        ),
      );
    }

    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _showSuccessPopup() {
    setState(() {
      showSuccessPopup = true;
    });
  }

  void _completeStep() {
    // Update order status in Firestore based on current step
    String statusField;
    String statusValue;

    if (widget.currentStep == 'arrived') {
      statusField = 'status';
      statusValue = 'picked_up';
    } else if (widget.currentStep == 'pickup') {
      statusField = 'status';
      statusValue = 'delivered';
    } else {
      return;
    }

    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      statusField: statusValue,
      '${statusValue}At': FieldValue.serverTimestamp(),
    }).then((_) {
      _showSuccessPopup();
      widget.onStepCompleted();
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status: $error')),
      );
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        chatMessages.add(_messageController.text);
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else if (currentPosition == null)
            Center(
                child: Text('Unable to determine your location',
                    style: TextStyle(color: Colors.white)))
          else
            GoogleMap(
              onMapCreated: (controller) {
                setState(() {
                  mapController = controller;
                  _moveCameraToRoute();
                });
              },
              initialCameraPosition: CameraPosition(
                target: currentPosition ?? LatLng(0, 0),
                zoom: 15.0,
              ),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: false,
            ),
          Positioned(
            top: 54,
            left: 16,
            right: 16,
            child: Header(
              onBackPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DeliveryDetails(
              deliveryProgress: deliveryProgress,
              estimatedTime: estimatedTime,
              currentStep: widget.currentStep,
              hasArrived: hasArrived,
              onActionPressed: _completeStep,
              onMessagePressed: () {
                setState(() {
                  showChatDialog = true;
                });
              },
            ),
          ),
          if (showSuccessPopup) _buildSuccessPopup(),
          if (showChatDialog) _buildChatDialog(),
        ],
      ),
    );
  }

  Widget _buildSuccessPopup() {
    String successText;
    if (widget.currentStep == 'arrived') {
      successText = 'Pickup Confirmed';
    } else if (widget.currentStep == 'pickup') {
      successText = 'Delivery Successful';
    } else {
      successText = 'Success';
    }

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 165.36,
              height: 164.97,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 88.31,
                  height: 73.21,
                  decoration: BoxDecoration(
                    color: Color(0xFF33BF7F),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              successText,
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: 36,
                height: 46 / 36,
                color: Color(0xFF0B7F40),
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.currentStep == 'pickup') {
                  AppNavigator.navigateToHome(context);
                } else {
                  widget.onStepCompleted();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0B7F40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: Size(341, 39),
                padding: EdgeInsets.symmetric(horizontal: 149, vertical: 9),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDialog() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Color(0xFF042E22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF0B7F40),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          showChatDialog = false;
                        });
                      },
                    ),
                    SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 20,
                      child: Icon(Icons.person, color: Color(0xFF0B7F40)),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentStep == 'arrived'
                                ? 'Farmer'
                                : 'Customer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Chat messages
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  reverse: false,
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    bool isMyMessage = index % 2 == 0;
                    return Align(
                      alignment: isMyMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMyMessage
                              ? Color(0xFF9EF84A)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chatMessages[index],
                          style: TextStyle(
                            color: isMyMessage ? Colors.black : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Message input
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        style: TextStyle(color: Colors.white),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Color(0xFF9EF84A)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final VoidCallback onBackPressed;

  const Header({
    Key? key,
    required this.onBackPressed,
  }) : super(key: key);

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
              onPressed: onBackPressed,
            ),
          ),
        ),

        // Centered title
        Center(
          child: Text(
            'Delivery',
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

class DeliveryDetails extends StatelessWidget {
  final double deliveryProgress;
  final String estimatedTime;
  final String currentStep;
  final bool hasArrived;
  final VoidCallback onActionPressed;
  final VoidCallback onMessagePressed;

  const DeliveryDetails({
    Key? key,
    required this.deliveryProgress,
    required this.estimatedTime,
    required this.currentStep,
    required this.hasArrived,
    required this.onActionPressed,
    required this.onMessagePressed,
  }) : super(key: key);

  String get actionButtonText {
    if (currentStep == 'arrived') return 'Confirm Pickup';
    if (currentStep == 'pickup') return 'Confirm Delivery';
    return 'Continue';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF042E22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: Colors.grey,
                  radius: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep == 'arrived'
                          ? 'Going to Pickup'
                          : 'Going to Delivery',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Estimated arrival: $estimatedTime',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF9EF84A),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.chat, color: Colors.white),
                  onPressed: onMessagePressed,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: deliveryProgress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9EF84A)),
            minHeight: 8,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: hasArrived ? onActionPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasArrived ? Color(0xFF9EF84A) : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              actionButtonText,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(child: BottomNavigationBarComponent(currentIndex: 2)),
        ],
      ),
    );
  }
}
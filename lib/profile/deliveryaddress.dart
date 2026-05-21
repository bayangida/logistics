import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bottom_nav_bar.dart';
import 'deliveryedit.dart';

class FleetManagementPage extends StatefulWidget {
  @override
  _FleetManagementPageState createState() => _FleetManagementPageState();
}

class _FleetManagementPageState extends State<FleetManagementPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _setDefaultFleet(String fleetId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Update all fleets to set isDefault to false
      final fleetSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('fleet')
          .get();

      final batch = _firestore.batch();
      for (final doc in fleetSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
      await batch.commit();

      // Set the selected fleet as default
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fleet')
          .doc(fleetId)
          .update({'isDefault': true});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Default fleet updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating default fleet: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteFleet(String fleetId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fleet')
          .doc(fleetId)
          .delete();
      await _firestore
          .collection('drivers')
          .doc(userId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fleet deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting fleet: ${e.toString()}')),
      );
    }
  }

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
                  .collection('users')
                  .doc(userId)
                  .collection('fleet')
                  .orderBy('isDefault', descending: true)
                  .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No Fleets saved yet',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Color(0xFF475569),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.all(16),
                  children: snapshot.data!.docs.map((doc) {
                    final fleet = doc.data() as Map<String, dynamic>;
                    return FleetCard(
                      fleetId: doc.id,
                      address: fleet['address'] ?? '',
                      city: fleet['city'] ?? '',
                      state: fleet['state'] ?? '',
                      zipCode: fleet['zipCode'] ?? '',
                      country: fleet['country'] ?? '',
                      license: fleet['license'] ?? '',
                      vehicletype: fleet['vehicleType'] ?? '',
                      Name: fleet['name'] ?? '',
                      colour: fleet['colour'] ?? '',
                      Model: fleet['model'] ?? '',
                      platenumber: fleet['plateNumber'] ?? '',
                      isDefault: fleet['isDefault'] ?? false,
                      onSetDefault: () => _setDefaultFleet(doc.id),
                      onDelete: () => _deleteFleet(doc.id),
                    );
                  }).toList(),
                );
              },
            ),
          ),

        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FleetEditPage()),
            );
          },
          backgroundColor: Colors.transparent, // Make the background transparent

          elevation: 0, // Remove shadow
          highlightElevation: 0,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Color(0xFF0B7F40),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add,
              color: Color(0xFF9EF84A),
              size: 24,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class FleetCard extends StatelessWidget {
  final String fleetId;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String license;
  final String vehicletype;
  final String Name;
  final String colour;
  final String Model;
  final String platenumber;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const FleetCard({
    required this.fleetId,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    required this.license,
    required this.vehicletype,
    required this.Name,
    required this.colour,
    required this.Model,
    required this.platenumber,
    required this.isDefault,
    required this.onSetDefault,
    required this.onDelete,
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
          color: isDefault ? Color(0xFF0B7F40) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicletype,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (isDefault)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF0B7F40).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEFAULT',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B7F40),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Driver: $Name',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'License: $license',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Vehicle: $Model ($colour)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Plate: $platenumber',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Location: $address, $city, $state $zipCode, $country',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDelete,
                child: Text(
                  'Delete',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
              SizedBox(width: 16),
              if (!isDefault)
                TextButton(
                  onPressed: onSetDefault,
                  child: Text(
                    'Set Default',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFF0B7F40),
                    ),
                  ),
                ),
              SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FleetEditPage(
                        fleetId: fleetId,
                        initialAddress: address,
                        initialCity: city,
                        initialState: state,
                        initialZipCode: zipCode,
                        initialCountry: country,
                        initialLicense: license,
                        initialVehicletype: vehicletype,
                        initialName: Name,
                        initialColour: colour,
                        initialModel: Model,
                        initialPlatenumber: platenumber,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF0B7F40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
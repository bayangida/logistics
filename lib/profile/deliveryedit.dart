import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bottom_nav_bar.dart';
import '../logistics/notificationstatus.dart';

class FleetEditPage extends StatefulWidget {
  final String? fleetId;
  final String? initialAddress;
  final String? initialCity;
  final String? initialState;
  final String? initialZipCode;
  final String? initialCountry;
  final String? initialLicense;
  final String? initialVehicletype;
  final String? initialName;
  final String? initialColour;
  final String? initialModel;
  final String? initialPlatenumber;

  const FleetEditPage({
    this.fleetId,
    this.initialAddress,
    this.initialCity,
    this.initialState,
    this.initialZipCode,
    this.initialCountry,
    this.initialLicense,
    this.initialVehicletype,
    this.initialName,
    this.initialColour,
    this.initialModel,
    this.initialPlatenumber,
  });

  @override
  _FleetEditPageState createState() => _FleetEditPageState();
}

class _FleetEditPageState extends State<FleetEditPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipCodeController;
  late TextEditingController _countryController;
  late TextEditingController _licenseController;
  late TextEditingController _vehicletypeController;
  late TextEditingController _nameController;
  late TextEditingController _colourController;
  late TextEditingController _modelController;
  late TextEditingController _platenumberController;
  bool _isLoading = false;
  bool _isDefault = false;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress ?? '');
    _cityController = TextEditingController(text: widget.initialCity ?? '');
    _stateController = TextEditingController(text: widget.initialState ?? '');
    _zipCodeController = TextEditingController(text: widget.initialZipCode ?? '');
    _countryController = TextEditingController(text: widget.initialCountry ?? '');
    _licenseController = TextEditingController(text: widget.initialLicense ?? '');
    _vehicletypeController = TextEditingController(text: widget.initialVehicletype ?? '');
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _colourController = TextEditingController(text: widget.initialColour ?? '');
    _modelController = TextEditingController(text: widget.initialModel ?? '');
    _platenumberController = TextEditingController(text: widget.initialPlatenumber ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _licenseController.dispose();
    _vehicletypeController.dispose();
    _nameController.dispose();
    _colourController.dispose();
    _modelController.dispose();
    _platenumberController.dispose();
    super.dispose();
  }

  Future<void> _saveFleet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final combinedAddress = '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()}, ${_zipCodeController.text.trim()}, ${_countryController.text.trim()}';

      final fleetData = {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
        'country': _countryController.text.trim(),
        'license': _licenseController.text.trim(),
        'vehicleType': _vehicletypeController.text.trim(),
        'name': _nameController.text.trim(),
        'colour': _colourController.text.trim(),
        'model': _modelController.text.trim(),
        'plateNumber': _platenumberController.text.trim(),
        'isDefault': _isDefault,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final driverData = {
        'name': _nameController.text.trim(),
        'phone': _auth.currentUser?.phoneNumber ?? '',
        'vehicleType': _vehicletypeController.text.trim(),
        'address': combinedAddress,
        'licenseNumber': _licenseController.text.trim(),
        'plateNumber': _platenumberController.text.trim(),
        'isAvailable': _isAvailable,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.fleetId == null) {
        // Add new fleet
        fleetData['createdAt'] = FieldValue.serverTimestamp();
        final fleetRef = await _firestore
            .collection('users')
            .doc(userId)
            .collection('fleet')
            .add(fleetData);

        // Use set with merge for drivers collection
        driverData['fleetId'] = fleetRef.id;
        driverData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('drivers').doc(userId).set(
          driverData,
          SetOptions(merge: true), // This will create or update
        );
      } else {
        // Update existing fleet
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('fleet')
            .doc(widget.fleetId)
            .update(fleetData);

        // Use set with merge for drivers collection
        await _firestore.collection('drivers').doc(userId).set(
          driverData,
          SetOptions(merge: true), // This will create or update
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fleet saved successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving fleet: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          HeaderComponent(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  _FleetInputField(
                    label: 'Vehicle Type',
                    controller: _vehicletypeController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter vehicle type';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'Driver Name',
                    controller: _nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter driver name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'Vehicle Color',
                    controller: _colourController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter vehicle color';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'Vehicle Model',
                    controller: _modelController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter vehicle model';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'License Plate Number',
                    controller: _platenumberController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter license plate number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: "Driver's License Number",
                    controller: _licenseController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter driver license number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'Address',
                    controller: _addressController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter address';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'City',
                    controller: _cityController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter city';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'State',
                    controller: _stateController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter state';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'Zip Code',
                    controller: _zipCodeController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter zip code';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _FleetInputField(
                    label: 'Country',
                    controller: _countryController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter country';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isAvailable,
                          onChanged: (value) {
                            setState(() {
                              _isAvailable = value ?? true;
                            });
                          },
                          activeColor: Color(0xFF0B7F40),
                        ),
                        Text(
                          'Available for deliveries',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.fleetId == null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isDefault,
                            onChanged: (value) {
                              setState(() {
                                _isDefault = value ?? false;
                              });
                            },
                            activeColor: Color(0xFF0B7F40),
                          ),
                          Text(
                            'Set as default fleet',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _SaveChangesButton(
              onPressed: _isLoading ? null : _saveFleet,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _FleetInputField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              errorStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
            ),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveChangesButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  const _SaveChangesButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0B7F40),
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : Text(
            'Save Changes',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
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
            padding: const EdgeInsets.only(top: 60.0,bottom: 28),
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
                  onPressed: () => Navigator.pop(
                    context,
                  ),
                ),
              ),
            ),
          ),

          // Centered title
          Padding(
            padding: const EdgeInsets.only(top: 60.0,bottom: 28),
            child: Center(
              child: Text(
                "Fleet management",
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
            padding: const EdgeInsets.only(top: 60.0,bottom: 28,right :9),
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
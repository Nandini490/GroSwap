import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;
  bool _loading = false;

  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _profileImageUrl = data['profileImageUrl'];
      }
    } catch (e) {
      _showSnack("Error loading profile: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      if (picked != null) setState(() => _profileImage = File(picked.path));
    } catch (e) {
      _showSnack("Error picking image: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showSnack("Enable location services");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack("Location permission denied forever");
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _addressController.text = "${place.street}, ${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      _showSnack("Error getting location: $e");
    }
  }

  Future<void> _pickOnMap() async {
    try {
      LatLng? picked = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapPickerScreen()),
      );

      if (picked != null) {
        final placemarks = await placemarkFromCoordinates(picked.latitude, picked.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            _addressController.text = "${place.street}, ${place.locality}, ${place.country}";
          });
        }
      }
    } catch (e) {
      _showSnack("Error picking location: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      String? imageUrl = _profileImageUrl;

      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_images/${user!.uid}.jpg');
        final uploadTask = storageRef.putFile(_profileImage!);

        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes * 100;
          print("Upload progress: ${progress.toStringAsFixed(2)}%");
        });

        await uploadTask.timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            _showSnack("Image upload timed out");
            throw Exception("Image upload timeout");
          },
        );

        imageUrl = await storageRef.getDownloadURL();
      }

      final data = {
        'uid': user!.uid,
        'email': user!.email,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(data, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception("Firestore save timeout");
            },
          );

      setState(() => _profileImageUrl = imageUrl);
      _showSnack("Profile saved successfully!");
    } catch (e) {
      _showSnack("Error saving profile: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.teal),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF507B7B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) as ImageProvider : null),
                        child: (_profileImage == null && _profileImageUrl == null)
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: user?.email ?? '',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter phone number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: "Address",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter address' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text("Auto Location"),
                            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF507B7B)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickOnMap,
                            icon: const Icon(Icons.map),
                            label: const Text("Pick on Map"),
                            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF507B7B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF507B7B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Save Profile"),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 236, 152, 152),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;
  LatLng _initialLocation = const LatLng(20.5937, 78.9629);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _goToUserLocation();
  }

  Future<void> _goToUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position pos = await Geolocator.getCurrentPosition();
      _initialLocation = LatLng(pos.latitude, pos.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_initialLocation, 15));
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _onMapTap(LatLng position) {
    setState(() => _pickedLocation = position);
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _onConfirm() {
    if (_pickedLocation != null) Navigator.pop(context, _pickedLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Pick Location", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _onConfirm),
        ],
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF507B7B)))
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: _initialLocation, zoom: 15),
              onTap: _onMapTap,
              onMapCreated: (controller) => _mapController = controller,
              markers: _pickedLocation != null
                  ? {Marker(markerId: const MarkerId("picked"), position: _pickedLocation!)}
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}

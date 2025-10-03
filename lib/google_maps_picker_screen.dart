import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapsPickerScreen extends StatefulWidget {
  const GoogleMapsPickerScreen({super.key});

  @override
  State<GoogleMapsPickerScreen> createState() => _GoogleMapsPickerScreenState();
}

class _GoogleMapsPickerScreenState extends State<GoogleMapsPickerScreen> {
  LatLng _pickedLocation = const LatLng(20.5937, 78.9629); // Default: center of India
  GoogleMapController? _mapController;

  void _onMapTap(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  void _onConfirm() {
    Navigator.pop(context, _pickedLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _onConfirm,
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _pickedLocation,
          zoom: 5,
        ),
        onMapCreated: (controller) => _mapController = controller,
        onTap: _onMapTap,
        markers: {
          Marker(
            markerId: const MarkerId('picked-location'),
            position: _pickedLocation,
          ),
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class GoogleMapsPickerScreen extends StatefulWidget {
  const GoogleMapsPickerScreen({super.key});

  @override
  State<GoogleMapsPickerScreen> createState() => _GoogleMapsPickerScreenState();
}

class _GoogleMapsPickerScreenState extends State<GoogleMapsPickerScreen> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _goToUserLocation();
  }

  // Request permission and get user location
  Future<void> _goToUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      setState(() => _loading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _loading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permission permanently denied. Enable it from settings')),
      );
      setState(() => _loading = false);
      return;
    }

    Position pos = await Geolocator.getCurrentPosition();
    _pickedLocation = LatLng(pos.latitude, pos.longitude);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_pickedLocation!, 15),
    );

    setState(() => _loading = false);
  }

  void _onMapTap(LatLng position) {
    setState(() => _pickedLocation = position);
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _onConfirm() {
    if (_pickedLocation != null) {
      Navigator.pop(context, _pickedLocation);
    }
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickedLocation ?? const LatLng(20.5937, 78.9629),
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTap,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _pickedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('picked-location'),
                        position: _pickedLocation!,
                      ),
                    }
                  : {},
            ),
    );
  }
}

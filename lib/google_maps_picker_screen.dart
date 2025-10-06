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
        const SnackBar(
          content: Text('Please enable location services'),
          backgroundColor: Color(0xFF004D40),
        ),
      );
      setState(() => _loading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied'),
            backgroundColor: Color(0xFF004D40),
          ),
        );
        setState(() => _loading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission permanently denied. Enable it from settings',
          ),
          backgroundColor: Color(0xFF004D40),
        ),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location first'),
          backgroundColor: Color(0xFF004D40),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        centerTitle: true,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _onConfirm,
          ),
        ],
      ),
      body: _loading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                GoogleMap(
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

                // Bottom info card
                if (_pickedLocation != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "📍 Selected Location",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _onConfirm,
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text(
                              "Confirm Location",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00796B),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

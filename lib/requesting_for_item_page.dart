import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import 'chat_screen.dart';

class RequestingForItemPage extends StatefulWidget {
  const RequestingForItemPage({super.key});

  @override
  State<RequestingForItemPage> createState() => _RequestingForItemPageState();
}

class _RequestingForItemPageState extends State<RequestingForItemPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _qtyCtl = TextEditingController();
  String category = 'Grocery';
  Position? _pos;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _determinePosition();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtl.dispose();
    _descCtl.dispose();
    _qtyCtl.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission =
          await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _pos = p);
    } catch (_) {}
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  double _distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter item name')));
      return;
    }
    setState(() => _sending = true);
    try {
      // Ensure we have a location for the request so it appears in Nearby Requests.
      if (_pos == null) {
        try {
          if (await Geolocator.isLocationServiceEnabled()) {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
              final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              if (mounted) setState(() => _pos = p);
            }
          }
        } catch (_) {
          // ignore: do nothing — location optional but recommended
        }
      }
      final data = {
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'name': name,
        'description': _descCtl.text.trim(),
        'quantity': _qtyCtl.text.trim(),
        'category': category,
        'status': 'open',
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (_pos != null) {
        data['locationGeoPoint'] = GeoPoint(_pos!.latitude, _pos!.longitude);
      }

      final doc =
          await FirebaseFirestore.instance.collection('requests').add(data);

      await FirebaseFirestore.instance.collection('my_requests').add({
        'userId': user.uid,
        'requestId': doc.id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request posted')));
      _nameCtl.clear();
      _descCtl.clear();
      _qtyCtl.clear();
      _tabController.animateTo(1);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _offerForRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final offerRef = FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .collection('offers');
    await offerRef.add({
      'responderId': user.uid,
      'responderEmail': user.email ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Offer sent')));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Item'),
        backgroundColor: AppTheme.terracotta,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.mediumBrown,
          unselectedLabelColor: AppTheme.mediumBrown.withOpacity(0.6),
          tabs: const [Tab(text: 'Request'), Tab(text: 'Nearby Requests')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Request form
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Item name',
                      filled: true,
                      fillColor: AppTheme.warmBeige.withOpacity(0.6),
                      labelStyle: const TextStyle(color: Colors.black87),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    )),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _descCtl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      filled: true,
                      fillColor: AppTheme.warmBeige.withOpacity(0.6),
                      labelStyle: const TextStyle(color: Colors.black87),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    )),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _qtyCtl,
                    decoration: InputDecoration(
                      labelText: 'Quantity (optional)',
                      filled: true,
                      fillColor: AppTheme.warmBeige.withOpacity(0.6),
                      labelStyle: const TextStyle(color: Colors.black87),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    )),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  items: ['Grocery', 'Gadgets', 'Stationery', 'Books', 'Clothing']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => category = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton.icon(
                      onPressed: _determinePosition,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use my location')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.list),
                      label: const Text('View nearby')),
                ]),
                const SizedBox(height: 12),
                if (_sending)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(onPressed: _sendRequest, child: const Text('Send Request')),
              ],
            ),
          ),

          // Nearby Requests
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.where((d) {
                final data = d.data();
                if (data['userId'] == user?.uid) return false;
                if (_pos == null || data['locationGeoPoint'] == null) return false;
                final gp = data['locationGeoPoint'];
                if (gp is! GeoPoint) return false;
                final dist = _distanceMeters(_pos!.latitude, _pos!.longitude, gp.latitude, gp.longitude);
                return dist <= 1000.0;
              }).toList();

              if (docs.isEmpty) return const Center(child: Text('No nearby requests', style: TextStyle(color: Color(0xFF6B4C3B))));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final r = docs[index];
                  final data = r.data();
                  final requester = (data['userEmail'] ?? data['userId'] ?? '').toString();

                  return Card(
                    color: AppTheme.mediumBrown.withOpacity(0.95),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Unnamed',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(data['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                                onPressed: () async => await _offerForRequest(r.id),
                                child: const Text('I have this'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                                onPressed: () {
                                  final otherId = data['userId'] ?? '';
                                  if (otherId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          otherUserId: otherId,
                                          otherUserName: requester,
                                          itemId: r.id, // <-- fix applied
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Chat'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

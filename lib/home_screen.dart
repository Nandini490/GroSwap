import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens
import 'add_item_screen.dart';
import 'mylist_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';
import 'requests_screen.dart';
import 'product_detail_screen.dart';
import 'requesting_for_item_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedCategory = 'All';
  String selectedSort = 'None';
  int _selectedIndex = 0;
  Position? _currentPosition;
  bool _locationDenied = false;

  final List<String> categories = [
    'All',
    'Grocery',
    'Gadgets',
    'Stationery',
    'Books',
    'Electronics',
    'Clothing',
  ];

  final List<String> sortOptions = [
    'None',
    'Price: Low → High',
    'Price: High → Low',
    'Expiry: Soonest First',
  ];

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationDenied = true);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationDenied = true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationDenied = true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() => _currentPosition = pos);
    } catch (_) {
      setState(() => _locationDenied = true);
    }
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    // Haversine
    const R = 6371000; // meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (3.14159265358979323846 / 180.0);

  Widget _buildHomeContent() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    Query<Map<String, dynamic>> itemsQuery = FirebaseFirestore.instance
        .collection('items')
        .orderBy('timestamp', descending: true);

    return SafeArea(
      child: Container(
        color: const Color(0xFFEDF4F3),
        child: Column(
          children: [
            if (_locationDenied)
              Container(
                color: Colors.orange[100],
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Location is disabled. Enable to see nearby items.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF507B7B),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF507B7B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        dropdownColor: const Color(0xFF507B7B),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: categories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedCategory = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF507B7B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedSort,
                        dropdownColor: const Color(0xFF507B7B),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: sortOptions
                            .map(
                              (sort) => DropdownMenuItem(
                                value: sort,
                                child: Text(sort),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedSort = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: itemsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF507B7B),
                      ),
                    );
                  }

                  final items = snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final search = _searchController.text.toLowerCase();

                    // Exclude items posted by the current user
                    if ((data['userId'] ?? '') == userId) return false;

                    // Match against either 'category' or 'type' (case-insensitive)
                    final itemCategory =
                        (data['category'] ?? data['type'] ?? '')
                            .toString()
                            .toLowerCase();
                    final categoryMatch =
                        selectedCategory == 'All' ||
                        itemCategory == selectedCategory.toLowerCase();

                    // proximity filtering: if item has locationGeoPoint and we have current position,
                    // include only if within 1km (1000 meters)
                    bool passesProximity = true;
                    if (_currentPosition != null &&
                        data['locationGeoPoint'] != null) {
                      final gp = data['locationGeoPoint'];
                      double lat = 0, lon = 0;
                      try {
                        lat = (gp.latitude ?? gp['latitude']) as double;
                        lon = (gp.longitude ?? gp['longitude']) as double;
                      } catch (_) {
                        // ignore malformed
                      }
                      final d = _distanceMeters(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        lat,
                        lon,
                      );
                      passesProximity = d <= 1000.0;
                    }

                    return name.contains(search) &&
                        categoryMatch &&
                        passesProximity;
                  }).toList();

                  // Sorting
                  if (selectedSort == 'Price: Low → High') {
                    items.sort(
                      (a, b) => ((a.data()['price'] ?? 0) as num).compareTo(
                        (b.data()['price'] ?? 0) as num,
                      ),
                    );
                  } else if (selectedSort == 'Price: High → Low') {
                    items.sort(
                      (a, b) => ((b.data()['price'] ?? 0) as num).compareTo(
                        (a.data()['price'] ?? 0) as num,
                      ),
                    );
                  } else if (selectedSort == 'Expiry: Soonest First' &&
                      selectedCategory.toLowerCase() == 'grocery') {
                    items.sort((a, b) {
                      final expiryA = a.data()['expiryDate'] != null
                          ? (a.data()['expiryDate'] as Timestamp).toDate()
                          : DateTime(2100);
                      final expiryB = b.data()['expiryDate'] != null
                          ? (b.data()['expiryDate'] as Timestamp).toDate()
                          : DateTime(2100);
                      return expiryA.compareTo(expiryB);
                    });
                  }

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No items found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0, // square cells
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final data = item.data();
                      final itemId = item.id;

                      final name = data['name'] ?? 'Unnamed';
                      final type =
                          (data['type'] ?? data['category'] ?? 'No Type')
                              .toString();
                      final price = data['price'] ?? 0;

                      // ✅ Image handling fix
                      final rawUrl = data['imageUrl'];
                      final imageUrl =
                          (rawUrl != null && rawUrl.toString().isNotEmpty)
                          ? rawUrl.toString()
                          : '';

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('wishlist')
                            .where('userId', isEqualTo: userId)
                            .where('itemId', isEqualTo: itemId)
                            .snapshots(),
                        builder: (context, wishlistSnapshot) {
                          final isFavorited =
                              wishlistSnapshot.hasData &&
                              wishlistSnapshot.data!.docs.isNotEmpty;

                          return Card(
                            color: Colors.white,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                        itemId: itemId,
                                        itemData: data,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Hero(
                                          tag: 'product_${itemId}_0',
                                          child: (imageUrl.isNotEmpty)
                                              ? Image.network(
                                                  imageUrl,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Image.asset(
                                                          'assets/images/placeholder.jpg',
                                                          fit: BoxFit.cover,
                                                        );
                                                      },
                                                )
                                              : Image.asset(
                                                  'assets/images/placeholder.jpg',
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF3A5F5F),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$type • ₹$price',
                                      style: const TextStyle(
                                        color: Color(0xFF6B6B6B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isFavorited
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: const Color(0xFF507B7B),
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            try {
                                              final wishlistRef =
                                                  FirebaseFirestore.instance
                                                      .collection('wishlist');

                                              final existing = await wishlistRef
                                                  .where(
                                                    'userId',
                                                    isEqualTo: userId,
                                                  )
                                                  .where(
                                                    'itemId',
                                                    isEqualTo: itemId,
                                                  )
                                                  .get();

                                              if (existing.docs.isNotEmpty) {
                                                final batch = FirebaseFirestore
                                                    .instance
                                                    .batch();
                                                for (var doc in existing.docs)
                                                  batch.delete(doc.reference);
                                                await batch.commit();
                                                if (mounted)
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Removed from wishlist',
                                                      ),
                                                    ),
                                                  );
                                              } else {
                                                await wishlistRef.add({
                                                  'userId': userId,
                                                  'itemId': itemId,
                                                  'timestamp':
                                                      FieldValue.serverTimestamp(),
                                                });
                                                if (mounted)
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Added to wishlist',
                                                      ),
                                                    ),
                                                  );
                                              }
                                            } catch (e) {
                                              if (mounted)
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Wishlist error: $e',
                                                    ),
                                                  ),
                                                );
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_shopping_cart,
                                            color: Color(0xFF507B7B),
                                            size: 20,
                                          ),
                                          tooltip: 'Add to cart',
                                          onPressed: () async {
                                            try {
                                              final cartRef = FirebaseFirestore
                                                  .instance
                                                  .collection('cart');

                                              final existingCart = await cartRef
                                                  .where(
                                                    'userId',
                                                    isEqualTo: userId,
                                                  )
                                                  .where(
                                                    'itemId',
                                                    isEqualTo: itemId,
                                                  )
                                                  .get();

                                              if (existingCart
                                                  .docs
                                                  .isNotEmpty) {
                                                if (mounted)
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Item already in cart',
                                                      ),
                                                    ),
                                                  );
                                              } else {
                                                await cartRef.add({
                                                  'userId': userId,
                                                  'itemId': itemId,
                                                  'timestamp':
                                                      FieldValue.serverTimestamp(),
                                                });
                                                if (mounted)
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Added to cart',
                                                      ),
                                                    ),
                                                  );
                                              }
                                            } catch (e) {
                                              if (mounted)
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Cart error: $e',
                                                    ),
                                                  ),
                                                );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<Widget> _otherTabs = const [
    PlaceholderScreen(title: 'Messages'),
    MyListScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [_buildHomeContent(), ..._otherTabs];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resourcely'),
        backgroundColor: const Color(0xFF507B7B),
        elevation: 0,
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WishlistScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.pending_actions, color: Colors.white),
                  tooltip: 'Requests',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RequestsScreen(),
                      ),
                    );
                  },
                ),
                  IconButton(
                    icon: const Icon(Icons.request_page, color: Colors.white),
                    tooltip: 'Request Item',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestingForItemPage(),
                        ),
                      );
                    },
                  ),
              ]
            : null,
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddItemScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF507B7B),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        onTap: _onBottomNavTap,
        backgroundColor: const Color(0xFF507B7B),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'MyList'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF4F3),
      body: SafeArea(
        child: Center(
          child: Text(
            '$title Screen Coming Soon',
            style: const TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ),
      ),
    );
  }
}

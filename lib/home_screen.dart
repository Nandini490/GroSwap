import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens
import 'add_item_screen.dart';
import 'mylist_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

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

  final List<String> categories = [
    'All',
    'Grocery',
    'Gadgets',
    'Stationery',
    'Books',
    'Electronics',
    'Clothing'
  ];

  final List<String> sortOptions = [
    'None',
    'Price: Low → High',
    'Price: High → Low',
    'Expiry: Soonest First'
  ];

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 🔹 HOME CONTENT
  Widget _buildHomeContent() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    Query<Map<String, dynamic>> itemsQuery = FirebaseFirestore.instance
        .collection('items')
        .orderBy('timestamp', descending: true);

    if (selectedCategory != 'All') {
      itemsQuery = itemsQuery.where('category', isEqualTo: selectedCategory);
    }

    return SafeArea(
      child: Container(
        color: const Color(0xFFEDF4F3), // subtle teal-white background
        child: Column(
          children: [
            // 🔍 Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF507B7B)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),

            // 🔽 Filters & Sorting
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
                            .map((cat) => DropdownMenuItem(
                                value: cat, child: Text(cat)))
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
                            .map((sort) => DropdownMenuItem(
                                value: sort, child: Text(sort)))
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

            // 🛍️ Items list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: itemsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF507B7B)));
                  }

                  List<QueryDocumentSnapshot<Map<String, dynamic>>> items =
                      snapshot.data!.docs.where((doc) {
                    final name = doc['name'].toString().toLowerCase();
                    final search = _searchController.text.toLowerCase();
                    return name.contains(search);
                  }).toList();

                  // Sorting logic
                  if (selectedSort == 'Price: Low → High') {
                    items.sort((a, b) =>
                        (a['price'] as num).compareTo(b['price'] as num));
                  } else if (selectedSort == 'Price: High → Low') {
                    items.sort((a, b) =>
                        (b['price'] as num).compareTo(a['price'] as num));
                  } else if (selectedSort == 'Expiry: Soonest First' &&
                      selectedCategory == 'Grocery') {
                    items.sort((a, b) {
                      final expiryA = a['expiryDate'] != null
                          ? (a['expiryDate'] as Timestamp).toDate()
                          : DateTime(2100);
                      final expiryB = b['expiryDate'] != null
                          ? (b['expiryDate'] as Timestamp).toDate()
                          : DateTime(2100);
                      return expiryA.compareTo(expiryB);
                    });
                  }

                  if (items.isEmpty) {
                    return const Center(
                        child: Text('No items found',
                            style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item.id;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('wishlist')
                            .where('userId', isEqualTo: userId)
                            .where('itemId', isEqualTo: itemId)
                            .snapshots(),
                        builder: (context, wishlistSnapshot) {
                          final isFavorited = wishlistSnapshot.hasData &&
                              wishlistSnapshot.data!.docs.isNotEmpty;

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                            child: ListTile(
                              leading: item['imageUrl'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        item['imageUrl'],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.image,
                                      color: Colors.grey, size: 40),
                              title: Text(
                                item['name'],
                                style: const TextStyle(
                                    color: Color(0xFF3A5F5F),
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['type']} • ₹${item['price']}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                  if (item['category'] == 'Grocery' &&
                                      item['expiryDate'] != null)
                                    Builder(builder: (context) {
                                      final expiry =
                                          (item['expiryDate'] as Timestamp)
                                              .toDate();
                                      final now = DateTime.now();
                                      final daysLeft =
                                          expiry.difference(now).inDays;

                                      String expiryText;
                                      Color expiryColor;

                                      if (daysLeft < 0) {
                                        expiryText = 'Expired!';
                                        expiryColor = Colors.red;
                                      } else if (daysLeft == 0) {
                                        expiryText = 'Expires today!';
                                        expiryColor = Colors.orange;
                                      } else {
                                        expiryText = 'Expires in $daysLeft days';
                                        expiryColor = daysLeft <= 3
                                            ? Colors.orange
                                            : Colors.green;
                                      }

                                      return Text(
                                        expiryText,
                                        style: TextStyle(
                                            color: expiryColor,
                                            fontWeight: FontWeight.w500),
                                      );
                                    }),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: const Color(0xFF507B7B),
                                ),
                                onPressed: () async {
                                  final wishlistRef = FirebaseFirestore.instance
                                      .collection('wishlist');
                                  if (isFavorited) {
                                    for (var doc
                                        in wishlistSnapshot.data!.docs) {
                                      await wishlistRef.doc(doc.id).delete();
                                    }
                                  } else {
                                    await wishlistRef.add({
                                      'userId': userId,
                                      'itemId': itemId,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                  }
                                },
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

  // 🔹 OTHER TABS
  final List<Widget> _otherTabs = const [
    PlaceholderScreen(title: 'Messages'),
    MyListScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeContent(),
      ..._otherTabs,
    ];

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
                          builder: (context) => const WishlistScreen()),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddItemScreen()),
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
              icon: Icon(Icons.shopping_cart), label: 'Cart'),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Wishlist', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('wishlist')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error loading wishlist:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => FirebaseFirestore.instance
                          .collection('wishlist')
                          .where('userId', isEqualTo: userId)
                          .orderBy('timestamp', descending: true)
                          .get(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Your wishlist is empty',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final wishlistItem = docs[index];
              final itemId = wishlistItem['itemId'];

              // Fetch full item details
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('items')
                    .doc(itemId)
                    .get(),
                builder: (context, itemSnap) {
                  if (itemSnap.hasError) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: ListTile(
                        title: const Text('Error loading item'),
                        subtitle: Text('${itemSnap.error}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('wishlist')
                                .doc(wishlistItem.id)
                                .delete();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Removed from wishlist'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }

                  if (itemSnap.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: Card(
                        child: SizedBox(
                          height: 72,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (!itemSnap.hasData || !itemSnap.data!.exists) {
                    // Item was removed from items collection
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Card(
                        color: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: const Text(
                            'Item no longer available',
                            style: TextStyle(color: Colors.black),
                          ),
                          subtitle: const Text(
                            'This item was removed by the owner.',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('wishlist')
                                  .doc(wishlistItem.id)
                                  .delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Removed from wishlist'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  }

                  final item = itemSnap.data!;

                  // Image URL fallback
                  final rawUrl = item['imageUrl'];
                  final imageUrl =
                      (rawUrl != null && rawUrl.toString().isNotEmpty)
                      ? rawUrl.toString()
                      : 'https://via.placeholder.com/150';

                  // Type fallback
                  final type = (item['type'] ?? item['category'] ?? 'No Type')
                      .toString();

                  return Card(
                    color: Colors.white,
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                      title: Text(
                        item['name'] ?? 'Unnamed',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$type • ₹${item['price'] ?? 0}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('wishlist')
                              .doc(wishlistItem.id)
                              .delete();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Removed from wishlist'),
                              ),
                            );
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
    );
  }
}

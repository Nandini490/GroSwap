import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Wishlist',
          style: TextStyle(color: Colors.black),
        ),
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
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          final docs = snapshot.data!.docs;

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
              return FutureBuilder(
                future: FirebaseFirestore.instance.collection('items').doc(itemId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final item = snapshot.data!;
                  return Card(
                    color: Colors.white,
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                          : const Icon(Icons.image, color: Colors.grey),
                      title: Text(
                        item['name'],
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item['type']} • \$${item['price']}',
                        style: const TextStyle(color: Colors.grey),
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

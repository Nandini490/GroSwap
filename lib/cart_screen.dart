import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF507B7B), // soft teal background
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Avoid server-side orderBy to prevent composite-index errors for some rules.
        stream: FirebaseFirestore.instance
            .collection('cart')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading cart:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF507B7B)),
            );
          }

          var cartDocs = snapshot.data!.docs;

          if (cartDocs.isEmpty) {
            return const Center(
              child: Text(
                '🛒 Your cart is empty',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          // Sort client-side by timestamp (descending)
          cartDocs.sort((a, b) {
            final aTs = a['timestamp'] is Timestamp
                ? (a['timestamp'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final bTs = b['timestamp'] is Timestamp
                ? (b['timestamp'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return bTs.compareTo(aTs);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cartDocs.length,
            itemBuilder: (context, index) {
              final cartItem = cartDocs[index];
              final itemId = cartItem['itemId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('items')
                    .doc(itemId)
                    .get(),
                builder: (context, itemSnapshot) {
                  // Guard against errors or missing documents
                  if (itemSnapshot.hasError) return const SizedBox();
                  if (!itemSnapshot.hasData) return const SizedBox();

                  final doc = itemSnapshot.data!;
                  if (!doc.exists) return const SizedBox();

                  final itemData =
                      (doc.data() as Map<String, dynamic>?) ??
                      <String, dynamic>{};

                  final imageUrl = (itemData['imageUrl'] ?? '').toString();
                  final name = (itemData['name'] ?? 'Unnamed').toString();
                  final type = (itemData['type'] ?? itemData['category'] ?? '')
                      .toString();
                  final price = itemData['price'] ?? 0;

                  return Card(
                    color: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image, color: Colors.grey),
                              ),
                            )
                          : const Icon(Icons.image, color: Colors.grey),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${type.isNotEmpty ? type + ' • ' : ''}₹$price',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('cart')
                              .doc(cartItem.id)
                              .delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Item removed from cart'),
                              backgroundColor: Color(0xFF507B7B),
                            ),
                          );
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

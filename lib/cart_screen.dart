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
        title: const Text(
          'My Cart',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cart')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF507B7B)),
            );
          }

          final cartDocs = snapshot.data!.docs;

          if (cartDocs.isEmpty) {
            return const Center(
              child: Text(
                '🛒 Your cart is empty',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cartDocs.length,
            itemBuilder: (context, index) {
              final cartItem = cartDocs[index];
              final itemId = cartItem['itemId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('items').doc(itemId).get(),
                builder: (context, itemSnapshot) {
                  if (!itemSnapshot.hasData) return const SizedBox();

                  final item = itemSnapshot.data!;
                  return Card(
                    color: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: item['imageUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${item['type'] ?? item['category']} • ₹${item['price']}',
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

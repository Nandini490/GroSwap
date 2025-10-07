import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF507B7B),
      appBar: AppBar(
        title: const Text('My List', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mylist')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final myListDocs = snapshot.data!.docs;

          if (myListDocs.isEmpty) {
            return const Center(
              child: Text(
                'No items in My List',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final itemIds = myListDocs.map((doc) => doc['itemId'] as String).toList();

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('items')
                .where(FieldPath.documentId, whereIn: itemIds)
                .get(),
            builder: (context, itemSnapshot) {
              if (!itemSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              // Map itemId → DocumentSnapshot
              final itemsData = {for (var doc in itemSnapshot.data!.docs) doc.id: doc};

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: myListDocs.length,
                itemBuilder: (context, index) {
                  final myListItem = myListDocs[index];
                  final itemId = myListItem['itemId'];
                  final item = itemsData[itemId];

                  if (item == null) return const SizedBox();

                  // Get image URL with fallback
                  final rawUrl = item['imageUrl'];
                  final imageUrl = (rawUrl != null && rawUrl.toString().isNotEmpty)
                      ? rawUrl.toString()
                      : 'https://via.placeholder.com/150';

                  // Get type with fallback
                  final type = (item['type'] ?? item['category'] ?? 'No Type').toString();

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 55,
                              height: 55,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
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
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
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
    );
  }
}

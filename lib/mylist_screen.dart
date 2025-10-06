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
  Map<String, DocumentSnapshot> itemsMap = {};

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

          // Get all itemIds
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

              // Map itemId → DocumentSnapshot for quick lookup
              final itemsData = {for (var doc in itemSnapshot.data!.docs) doc.id: doc};

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: myListDocs.length,
                itemBuilder: (context, index) {
                  final myListItem = myListDocs[index];
                  final itemId = myListItem['itemId'];
                  final item = itemsData[itemId];

                  if (item == null) return const SizedBox();

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: item['imageUrl'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['imageUrl'],
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image, color: Colors.grey),
                        title: Text(
                          item['name'],
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${item['type']} • \$${item['price']}',
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

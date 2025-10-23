import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_detail_screen.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _removeFromMyList(String mylistDocId) async {
    await FirebaseFirestore.instance
        .collection('mylist')
        .doc(mylistDocId)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from My List')));
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Delete Item?",
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          "Are you sure? Irreversible.",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.terracotta),
      ),
    );

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Delete mylist entries for this user referencing the item
      final mylistQuery = await FirebaseFirestore.instance
          .collection('mylist')
          .where('userId', isEqualTo: user.uid)
          .where('itemId', isEqualTo: itemId)
          .get();
      for (var d in mylistQuery.docs) {
        batch.delete(d.reference);
      }

      // Delete the item document
      final itemRef = FirebaseFirestore.instance
          .collection('items')
          .doc(itemId);
      batch.delete(itemRef);

      await batch.commit();

        // pop loading
        if (mounted) Navigator.of(context).pop();

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted!')));
    } catch (e) {
      // pop loading
      if (mounted) Navigator.of(context).pop();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _editItem(String itemId, Map<String, dynamic> currentData) async {
    final TextEditingController nameController = TextEditingController(
      text: currentData['name'],
    );
    final TextEditingController priceController = TextEditingController(
      text: currentData['price'].toString(),
    );
    final TextEditingController typeController = TextEditingController(
      text: currentData['type'] ?? currentData['category'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Edit Item", style: TextStyle(color: Colors.black)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Item Name"),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: "Type / Category",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFFE07A5F))),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('items')
                    .doc(itemId)
                    .update({
                      'name': nameController.text,
                      'price': double.tryParse(priceController.text) ?? 0,
                      'type': typeController.text,
                    });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Item updated successfully")),
                );
              },
              child: const Text("Save", style: TextStyle(color: Color(0xFFE07A5F))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBeige,
      appBar: AppBar(
        title: const Text('My List', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to the user's mylist entries which reference itemIds
        stream: FirebaseFirestore.instance
            .collection('mylist')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.terracotta),
            );
          }

          final mylistDocs = snapshot.data!.docs;

          if (mylistDocs.isEmpty) {
            return const Center(
              child: Text(
                'You haven’t saved any items yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: mylistDocs.length,
            itemBuilder: (context, index) {
              final myDoc = mylistDocs[index];
              final myData = myDoc.data() as Map<String, dynamic>;
              final itemId = myData['itemId'] as String;

              // For each mylist entry, fetch the corresponding item document
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('items')
                    .doc(itemId)
                    .get(),
                builder: (context, itemSnap) {
                  if (itemSnap.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const SizedBox(
                        height: 72,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (!itemSnap.hasData || !itemSnap.data!.exists) {
                    // Item was removed from items collection
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
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
                            onPressed: () => _removeFromMyList(myDoc.id),
                          ),
                        ),
                      ),
                    );
                  }

                  final itemDoc = itemSnap.data!;
                  final data = itemDoc.data() as Map<String, dynamic>;

                  final name = data['name'] ?? 'Unnamed';
                  final type = (data['type'] ?? data['category'] ?? 'No Type')
                      .toString();
                  final price = data['price'] ?? 0;
                  final quantity = data['quantity'] ?? '';
                  final unit = data['unit'] ?? '';
          final rawUrl = data['imageUrl'];
          // prefer a local fallback image to avoid network failures on web/offline
          final imageUrl = (rawUrl != null && rawUrl.toString().isNotEmpty)
            ? rawUrl.toString()
            : 'assets/images/placeholder.jpg';
          final bool isNetworkImage = imageUrl.startsWith('http') && !imageUrl.contains('via.placeholder.com');

                  DateTime? expiryDate;
                  if (data['expiryDate'] != null) {
                    expiryDate = (data['expiryDate'] as Timestamp).toDate();
                  }

                  final isOwner = (data['userId'] ?? '') == userId;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                itemId: itemDoc.id,
                                itemData: data,
                              ),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isNetworkImage
                              ? Image.network(
                                  imageUrl,
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 55,
                                    height: 55,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/placeholder.jpg',
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$type • ₹$price',
                              style: const TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (quantity.toString().isNotEmpty ||
                                unit.toString().isNotEmpty)
                              Text(
                                'Quantity: $quantity $unit',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            if (expiryDate != null)
                              Text(
                                'Expiry: ${expiryDate.toLocal().toString().split(' ')[0]}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (value) async {
                            if (value == 'remove') {
                              await _removeFromMyList(myDoc.id);
                            } else if (value == 'edit' && isOwner) {
                              _editItem(itemDoc.id, data);
                            } else if (value == 'delete' && isOwner) {
                              _deleteItem(itemDoc.id);
                              // also remove any mylist entries referencing this item
                              final batch = FirebaseFirestore.instance.batch();
                              final mylistQuery = await FirebaseFirestore
                                  .instance
                                  .collection('mylist')
                                  .where('itemId', isEqualTo: itemDoc.id)
                                  .get();
                              for (var d in mylistQuery.docs) {
                                batch.delete(d.reference);
                              }
                              await batch.commit();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove'),
                            ),
                            if (isOwner)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                            if (isOwner)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
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
    );
  }
}

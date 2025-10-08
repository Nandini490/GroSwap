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

  void _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Delete Item", style: TextStyle(color: Colors.black)),
        content: const Text(
          "Are you sure you want to delete this item?",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('items').doc(itemId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item deleted successfully")),
      );
    }
  }

  void _editItem(String itemId, Map<String, dynamic> currentData) async {
    final TextEditingController nameController =
        TextEditingController(text: currentData['name']);
    final TextEditingController priceController =
        TextEditingController(text: currentData['price'].toString());
    final TextEditingController typeController =
        TextEditingController(text: currentData['type'] ?? currentData['category'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Edit Item",
            style: TextStyle(color: Colors.black),
          ),
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
                  decoration: const InputDecoration(labelText: "Type / Category"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.teal)),
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
              child: const Text("Save", style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF4F3),
      appBar: AppBar(
        title: const Text(
          'My Listings',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('items')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF507B7B)),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'You haven’t listed any items yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final itemId = doc.id;

              final name = data['name'] ?? 'Unnamed';
              final type = (data['type'] ?? data['category'] ?? 'No Type').toString();
              final price = data['price'] ?? 0;
              final quantity = data['quantity'] ?? '';
              final unit = data['unit'] ?? '';
              final rawUrl = data['imageUrl'];
              final imageUrl = (rawUrl != null && rawUrl.toString().isNotEmpty)
                  ? rawUrl.toString()
                  : 'https://via.placeholder.com/150';

              DateTime? expiryDate;
              if (data['expiryDate'] != null) {
                expiryDate = (data['expiryDate'] as Timestamp).toDate();
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Card(
                  color: Colors.white,
                  elevation: 3,
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
                    title: Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$type • ₹$price', style: const TextStyle(color: Colors.grey)),
                        if (quantity.isNotEmpty || unit.isNotEmpty)
                          Text('Quantity: $quantity $unit', style: const TextStyle(color: Colors.grey)),
                        if (expiryDate != null)
                          Text('Expiry: ${expiryDate.toLocal().toString().split(' ')[0]}',
                              style: const TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editItem(itemId, data);
                        } else if (value == 'delete') {
                          _deleteItem(itemId);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

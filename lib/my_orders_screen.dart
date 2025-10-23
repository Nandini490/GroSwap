import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'product_detail_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppTheme.warmBeige,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(color: Color(0xFF6B4C3B))),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('myOrders')
            .where('buyerId', isEqualTo: userId)
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, 
                       size: 64, 
                       color: AppTheme.mediumBrown.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No completed orders yet',
                    style: TextStyle(
                      color: AppTheme.mediumBrown,
                      fontSize: 18,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] as String? ?? '';
              final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [imageUrl];
              final name = data['itemName'] as String? ?? 'Unnamed Product';
              final price = data['price'] ?? 0;
              final type = data['type'] as String? ?? data['category'] as String? ?? '';
              final completedDate = (data['completedAt'] as Timestamp?)?.toDate();
              final itemId = data['itemId'] as String? ?? '';

              return Card(
                color: Colors.white,
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrls.isNotEmpty
                            ? SizedBox(
                                width: 60,
                                height: 60,
                                child: PageView.builder(
                                  itemCount: imageUrls.length,
                                  itemBuilder: (context, imgIndex) {
                                    return Image.network(
                                      imageUrls[imgIndex],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image,
                                                color: Colors.grey),
                                          ),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: AppTheme.mediumBrown,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (type.isNotEmpty)
                              Text(
                                type,
                                style: TextStyle(
                                  color: AppTheme.mediumBrown.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${price.toString()}',
                              style: TextStyle(
                                color: AppTheme.mediumBrown.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (completedDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Received on ${_formatDate(completedDate)}',
                                style: TextStyle(
                                  color: AppTheme.mediumBrown.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (itemId.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('items')
                                      .doc(itemId)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data!.exists) {
                                      return ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.terracotta,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4
                                          ),
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProductDetailScreen(
                                                itemId: itemId,
                                                itemData: snapshot.data!.data() as Map<String, dynamic>,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'View Original Item',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

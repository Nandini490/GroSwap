import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ReceivedProductButton extends StatelessWidget {
  final String itemId;
  final String itemName;
  final String imageUrl;
  final num price;
  final String buyerId;
  final String sellerId;
  final String cartItemId;

  const ReceivedProductButton({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.imageUrl,
    required this.price,
    required this.buyerId,
    required this.sellerId,
    required this.cartItemId,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap
      ),
      onPressed: () async {
        // Create a batch for atomic operations
        final batch = FirebaseFirestore.instance.batch();
        
        // Add to myOrders
        final myOrderRef = FirebaseFirestore.instance.collection('myOrders').doc();
        // Get the original item data for complete info (safe access)
        final itemDoc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
        final itemMap = <String, dynamic>{};
        if (itemDoc.exists) {
          final d = itemDoc.data();
          if (d is Map<String, dynamic>) itemMap.addAll(d);
        }

        // Get the cart document to capture original cart timestamp or extra fields
        final cartDocSnapshot = await FirebaseFirestore.instance.collection('cart').doc(cartItemId).get();
        final cartMap = <String, dynamic>{};
        if (cartDocSnapshot.exists) {
          final c = cartDocSnapshot.data();
          if (c is Map<String, dynamic>) cartMap.addAll(c);
        }

        // Combine item data with order-specific fields
        final orderData = <String, dynamic>{
          'itemId': itemId,
          'itemName': itemName,
          'imageUrl': imageUrl,
          'imageUrls': itemMap['imageUrls'] ?? (imageUrl.isNotEmpty ? [imageUrl] : null),
          'price': price,
          'buyerId': buyerId,
          'sellerId': sellerId,
          'completedAt': FieldValue.serverTimestamp(),
          // also include a generic timestamp field for ordering/queries
          'timestamp': FieldValue.serverTimestamp(),
          // Preserve original cart timestamp if available
          'cartTimestamp': cartMap['timestamp'] ?? null,
          // Additional fields from the original item (safe lookups)
          'type': itemMap['type'] ?? itemMap['category'],
          'description': itemMap['description'],
          'category': itemMap['category'],
          'condition': itemMap['condition'],
          'status': 'completed',
        };

        batch.set(myOrderRef, orderData);
        
        // Delete from cart
        batch.delete(FirebaseFirestore.instance.collection('cart').doc(cartItemId));
        
        try {
          await batch.commit();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Item marked as received!'),
                backgroundColor: AppTheme.terracotta,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: const Text(
        'Received Product',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500
        ),
      ),
    );
  }
}
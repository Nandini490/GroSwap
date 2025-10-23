import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:groswap/chat_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
  backgroundColor: AppTheme.warmBeige,
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(color: Color(0xFF6B4C3B))),
        centerTitle: true,
        backgroundColor: Colors.white,
        // keep icons black for contrast, only the title text is medium brown
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                child: CircularProgressIndicator(color: Colors.white));
          }

          final cartDocs = snapshot.data!.docs;

          if (cartDocs.isEmpty) {
            return const Center(
              child: Text('🛒 Your cart is empty',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            );
          }

          cartDocs.sort((a, b) {
            final aTs = (a['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTs = (b['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTs.compareTo(aTs);
          });

          final allItemsFuture = Future.wait(cartDocs.map((cartItem) {
            final itemId = cartItem['itemId'];
            return FirebaseFirestore.instance.collection('items').doc(itemId).get();
          }).toList());

          return FutureBuilder<List<DocumentSnapshot>>(
            future: allItemsFuture,
            builder: (context, itemsSnap) {
              if (itemsSnap.hasError) {
                return Center(
                    child: Text('Error loading items: ${itemsSnap.error}',
                        style: const TextStyle(color: Colors.white)));
              }

              if (!itemsSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              final itemsDocs = itemsSnap.data!;
              double grandTotal = 0.0;
              for (var doc in itemsDocs) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>?;
                  final price = data?['price'];
                  if (price is num) grandTotal += price.toDouble();
                }
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: cartDocs.length,
                      itemBuilder: (context, index) {
                        final cartItem = cartDocs[index];
                        final itemDoc = itemsDocs[index];

                        if (!itemDoc.exists) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: const Text('Item no longer available'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () {
                                  FirebaseFirestore.instance.collection('cart').doc(cartItem.id).delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: const Text('Item removed from cart'),
                                        backgroundColor: AppTheme.terracotta));
                                },
                              ),
                            ),
                          );
                        }

                        final itemData = itemDoc.data() as Map<String, dynamic>? ?? {};
                        final imageUrls = ((itemData['imageUrls'] as List<dynamic>?) ?? [])
                            .map((e) => e.toString())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        final fallbackImage = (itemData['imageUrl'] ?? '').toString();
                        final displayImages =
                            imageUrls.isNotEmpty ? imageUrls : (fallbackImage.isNotEmpty ? [fallbackImage] : <String>[]);

                        final name = (itemData['name'] ?? 'Unnamed').toString();
                        final ownerId = (itemData['userId'] ?? '').toString();
                        final type = (itemData['type'] ?? itemData['category'] ?? '').toString();
                        final price = itemData['price'] ?? 0;

                        return Card(
                          color: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(itemId: itemDoc.id, itemData: itemData)));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: displayImages.isNotEmpty
                                        ? Image.network(displayImages.first,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.image, color: Colors.grey))
                                        : const Icon(Icons.image, color: Colors.grey, size: 40),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                    Text(name,
                      style: TextStyle(
                        color: AppTheme.mediumBrown,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                    Text(
                      '${type.isNotEmpty ? "$type • " : ""}₹$price',
                      style: TextStyle(
                        color: AppTheme.mediumBrown.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 120),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          tooltip: 'Remove from cart',
                                          onPressed: () async {
                                            try {
                                              await FirebaseFirestore.instance.collection('cart').doc(cartItem.id).delete();
                                              if (mounted)
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                      content: const Text('Item removed from cart'),
                                                      backgroundColor: AppTheme.terracotta));
                                            } catch (e) {
                                              if (mounted)
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Remove failed: $e')));
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 6),

                                        // Place Order button
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('requests')
                                              .where('requesterId', isEqualTo: userId)
                                              .where('itemId', isEqualTo: cartItem['itemId'] ?? '')
                                              .snapshots(),
                                          builder: (context, reqSnap) {
                                            final hasRequest = reqSnap.hasData && reqSnap.data!.docs.isNotEmpty;
                                            return ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.terracotta,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: const Size(0, 0),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              onPressed: hasRequest
                                                  ? null
                                                  : () async {
                                                      final user = FirebaseAuth.instance.currentUser;
                                                      if (user == null) return;
                                                      if (ownerId == user.uid) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Cannot order your own item')));
                                                        return;
                                                      }
                                                      await FirebaseFirestore.instance.collection('requests').add({
                                                        'itemId': cartItem['itemId'],
                                                        'itemName': name,
                                                        'requesterId': user.uid,
                                                        'requesterEmail': user.email ?? '',
                                                        'ownerId': ownerId,
                                                        'status': 'pending',
                                                        'timestamp': FieldValue.serverTimestamp()
                                                      });
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Order placed successfully')));
                                                    },
                                              child: const Text('Place Order',
                                                  style: TextStyle(color: Colors.white, fontSize: 10)),
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 6),

                                        // Show status + call/message icons
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('requests')
                                              .where('requesterId', isEqualTo: userId)
                                              .where('itemId', isEqualTo: cartItem['itemId'] ?? '')
                                              .snapshots(),
                                          builder: (context, rs) {
                                            if (!rs.hasData || rs.data!.docs.isEmpty) return const SizedBox.shrink();
                                            final r = rs.data!.docs.first;
                                            final st = (r['status'] ?? 'pending').toString();
                                            String label;
                                            Color color;
                                            switch (st) {
                                              case 'accepted':
                                                label = '🟢 Accepted';
                                                color = Colors.green;
                                                break;
                                              case 'rejected':
                                                label = '🔴 Rejected';
                                                color = Colors.red;
                                                break;
                                              default:
                                                label = '🟡 Pending';
                                                color = Colors.orange;
                                            }

                                            return Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 6,
                                              children: [
                                                Text(label,
                                                    style: TextStyle(
                                                        color: color,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600)),
                                                if (st == 'accepted')
                                                  FutureBuilder<DocumentSnapshot?>(
                                                    future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
                                                    builder: (context, ownerSnap) {
                                                      if (!ownerSnap.hasData || !ownerSnap.data!.exists)
                                                        return const SizedBox.shrink();
                                                      final ownerData = ownerSnap.data!.data() as Map<String, dynamic>?;

                                                      final ownerPhone = (ownerData?['phone'] ?? '').toString();
                                                      final ownerName = (ownerData?['name'] ?? 'Seller').toString();

                                                      return Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.call, color: Colors.green, size: 14),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                                            onPressed: ownerPhone.isNotEmpty
                                                                ? () async {
                                                                    final uri = Uri(scheme: 'tel', path: ownerPhone);
                                                                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                                                                  }
                                                                : null,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.message, color: Color(0xFFE07A5F), size: 14),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                                            onPressed: () {
                                                              Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder: (_) => ChatScreen(
                                                                          otherUserId: ownerId,
                                                                          otherUserName: ownerName,
                                                                          itemId: cartItem['itemId'] ?? '')));
                                                            },
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Checkout bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total', style: TextStyle(color: Colors.grey)),
                            Text('₹${grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.terracotta,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Proceeding to checkout — total ₹${grandTotal.toStringAsFixed(2)}')));
                          },
                          child: const Text('Proceed to checkout'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

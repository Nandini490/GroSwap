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
                        final itemId = cartItem['itemId'] ?? '';

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('requests')
                              .where('requesterId', isEqualTo: userId)
                              .where('itemId', isEqualTo: itemId)
                              .snapshots(),
                          builder: (context, reqSnap) {
                            final hasRequest = reqSnap.hasData && reqSnap.data!.docs.isNotEmpty;
                            String status = 'none';
                            Map<String, dynamic>? requestData;
                            if (hasRequest) {
                              final r = reqSnap.data!.docs.first;
                              requestData = r.data() as Map<String, dynamic>? ?? {};
                              status = (requestData['status'] ?? 'pending').toString();
                            }

                            final itemExists = itemDoc.exists;
                            final isUnavailable = !itemExists && status != 'accepted';

                            if (isUnavailable) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: const Text('Item no longer available'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () {
                                      FirebaseFirestore.instance.collection('cart').doc(cartItem.id).delete();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Item removed from cart'),
                                            backgroundColor: AppTheme.terracotta));
                                    },
                                  ),
                                ),
                              );
                            }

                            // Prepare display data
                            String name = 'Unnamed';
                            dynamic price = 0;
                            String typeStr = '';
                            String ownerIdStr = '';
                            List<String> imageList = [];
                            bool canTapDetail = true;
                            Map<String, dynamic>? itemDataForDetail;

                            if (itemExists) {
                              final itemData = itemDoc.data() as Map<String, dynamic>? ?? {};
                              itemDataForDetail = itemData;
                              final imageUrls = ((itemData['imageUrls'] as List<dynamic>?) ?? [])
                                  .map((e) => e.toString())
                                  .where((s) => s.isNotEmpty)
                                  .toList();
                              final fallbackImage = (itemData['imageUrl'] ?? '').toString();
                              imageList = imageUrls.isNotEmpty
                                  ? imageUrls
                                  : (fallbackImage.isNotEmpty ? [fallbackImage] : <String>[]);
                              name = (itemData['name'] ?? 'Unnamed').toString();
                              ownerIdStr = (itemData['userId'] ?? '').toString();
                              typeStr = (itemData['type'] ?? itemData['category'] ?? '').toString();
                              price = itemData['price'] ?? 0;
                            } else {
                              // Accepted without item
                              name = (requestData?['itemName'] ?? 'Unnamed').toString();
                              price = requestData?['price'] ?? 0;
                              ownerIdStr = (requestData?['ownerId'] ?? '').toString();
                              canTapDetail = false;
                            }

                            final double priceNum = price is num ? price.toDouble() : 0.0;

                            return Card(
                              color: Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: InkWell(
                                onTap: canTapDetail
                                    ? () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => ProductDetailScreen(
                                                    itemId: itemDoc.id, itemData: itemDataForDetail ?? {})));
                                      }
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: imageList.isNotEmpty
                                            ? Image.network(
                                                imageList.first,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.image, color: Colors.grey),
                                              )
                                            : const Icon(Icons.image, color: Colors.grey, size: 40),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: AppTheme.mediumBrown,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${typeStr.isNotEmpty ? "$typeStr • " : ""}₹$priceNum',
                                              style: TextStyle(
                                                color: AppTheme.mediumBrown.withOpacity(0.85),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
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
                                                      const SnackBar(
                                                          content: Text('Item removed from cart'),
                                                          backgroundColor: AppTheme.terracotta));
                                                } catch (e) {
                                                  if (mounted)
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Remove failed: $e')));
                                                }
                                              },
                                            ),
                                            const SizedBox(height: 6),
                                            if (itemExists) ...[
                                              // Place Order button
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.terracotta,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: const Size(0, 0),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: hasRequest
                                                    ? null
                                                    : () async {
                                                        final user = FirebaseAuth.instance.currentUser;
                                                        if (user == null) return;
                                                        if (ownerIdStr == user.uid) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Cannot order your own item')));
                                                          return;
                                                        }
                                                        await FirebaseFirestore.instance.collection('requests').add({
                                                          'itemId': itemId,
                                                          'itemName': name,
                                                          'price': priceNum,
                                                          'requesterId': user.uid,
                                                          'requesterEmail': user.email ?? '',
                                                          'ownerId': ownerIdStr,
                                                          'status': 'pending',
                                                          'timestamp': FieldValue.serverTimestamp(),
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Order placed successfully')));
                                                      },
                                                child: const Text('Place Order',
                                                    style: TextStyle(color: Colors.white, fontSize: 10)),
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            if (hasRequest) ...[
                                              // Status + call/message icons + received button
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Wrap(
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    spacing: 6,
                                                    children: [
                                                      Text(
                                                        () {
                                                          String label;
                                                          Color color;
                                                          switch (status) {
                                                            case 'accepted':
                                                              label = '🟢 Accepted';
                                                              color = Colors.green;
                                                              break;
                                                            case 'completed':
                                                              label = '✅ Completed';
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
                                                          return label;
                                                        }(),
                                                        style: TextStyle(
                                                          color: () {
                                                            switch (status) {
                                                              case 'accepted':
                                                              case 'completed':
                                                                return Colors.green;
                                                              case 'rejected':
                                                                return Colors.red;
                                                              default:
                                                                return Colors.orange;
                                                            }
                                                          }(),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (status == 'accepted')
                                                        FutureBuilder<DocumentSnapshot?>(
                                                          future: FirebaseFirestore.instance.collection('users').doc(ownerIdStr).get(),
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
                                                                                otherUserId: ownerIdStr,
                                                                                otherUserName: ownerName,
                                                                                itemId: itemId)));
                                                                  },
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                  if (status == 'accepted')
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppTheme.terracotta,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          minimumSize: const Size(0, 0),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        onPressed: () async {
                                                          if (!hasRequest) return;
                                                          final requestDoc = reqSnap.data!.docs.first;
                                                          try {
                                                            await FirebaseFirestore.instance
                                                                .collection('requests')
                                                                .doc(requestDoc.id)
                                                                .update({
                                                              'status': 'completed',
                                                              'completedTimestamp': FieldValue.serverTimestamp(),
                                                            });
                                                            await FirebaseFirestore.instance
                                                                .collection('cart')
                                                                .doc(cartItem.id)
                                                                .delete();
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text('Transaction completed! Item removed from cart.'),
                                                                  backgroundColor: AppTheme.terracotta,
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Failed to mark as received: $e')),
                                                              );
                                                            }
                                                          }
                                                        },
                                                        child: const Text(
                                                          'Mark as Received',
                                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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
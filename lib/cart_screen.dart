import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:groswap/chat_screen.dart';

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

          // Fetch all item documents referenced by the cart so we can compute a grand total
          final allItemsFuture = Future.wait(
            cartDocs.map((cartItem) {
              final itemId = cartItem['itemId'];
              return FirebaseFirestore.instance
                  .collection('items')
                  .doc(itemId)
                  .get();
            }).toList(),
          );

          return FutureBuilder<List<DocumentSnapshot>>(
            future: allItemsFuture,
            builder: (context, itemsSnap) {
              if (itemsSnap.hasError) {
                return Center(
                  child: Text(
                    'Error loading items: ${itemsSnap.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              if (!itemsSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF507B7B)),
                );
              }

              final itemsDocs = itemsSnap.data!;

              // Compute grand total (each cart entry counts once)
              double grandTotal = 0.0;
              for (var doc in itemsDocs) {
                if (doc.exists) {
                  final data = (doc.data() as Map<String, dynamic>?) ?? {};
                  final price = data['price'];
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
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
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
                        }

                        final itemData =
                            (itemDoc.data() as Map<String, dynamic>?) ?? {};
                        // Support multiple images saved as `imageUrls` (new)
                        // while keeping `imageUrl` (fallback) for backward compatibility.
                        final imageUrls =
                            ((itemData['imageUrls'] as List<dynamic>?) ??
                                    <dynamic>[])
                                .map((e) => e.toString())
                                .where((s) => s.isNotEmpty)
                                .toList();
                        final fallbackImage = (itemData['imageUrl'] ?? '')
                            .toString();
                        final displayImages = imageUrls.isNotEmpty
                            ? imageUrls
                            : (fallbackImage.isNotEmpty
                                  ? [fallbackImage]
                                  : <String>[]);

                        final name = (itemData['name'] ?? 'Unnamed').toString();
                        final ownerId = (itemData['userId'] ?? '').toString();
                        final type =
                            (itemData['type'] ?? itemData['category'] ?? '')
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
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            leading: displayImages.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      displayImages.first,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.image,
                                                color: Colors.grey,
                                              ),
                                    ),
                                  )
                                : const Icon(Icons.image, color: Colors.grey),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${type.isNotEmpty ? type + ' • ' : ''}₹$price',
                              style: const TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Column with Request button and live status under it
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final itemId =
                                            cartItem['itemId']?.toString() ??
                                            '';
                                        // Stream of any requests by this user for this item
                                        final requestStream = FirebaseFirestore
                                            .instance
                                            .collection('requests')
                                            .where(
                                              'requesterId',
                                              isEqualTo: userId,
                                            )
                                            .where('itemId', isEqualTo: itemId)
                                            .snapshots();

                                        return StreamBuilder<QuerySnapshot>(
                                          stream: requestStream,
                                          builder: (context, reqSnap) {
                                            final hasRequest =
                                                reqSnap.hasData &&
                                                reqSnap.data!.docs.isNotEmpty;
                                            if (hasRequest) {
                                              // we will read the status below from the request doc when rendering the label
                                            }

                                            // Request button disabled if any request exists
                                            return ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF507B7B,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                minimumSize: const Size(0, 0),
                                              ),
                                              onPressed: hasRequest
                                                  ? null
                                                  : () async {
                                                      try {
                                                        final user =
                                                            FirebaseAuth
                                                                .instance
                                                                .currentUser;
                                                        if (user == null)
                                                          return;
                                                        final requesterId =
                                                            user.uid;
                                                        final requesterEmail =
                                                            user.email ?? '';
                                                        final ownerId =
                                                            (itemData['userId'] ??
                                                                    '')
                                                                .toString();

                                                        if (ownerId ==
                                                            requesterId) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Cannot order your own item',
                                                              ),
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        final reqRef =
                                                            FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                  'requests',
                                                                );
                                                        final existing =
                                                            await reqRef
                                                                .where(
                                                                  'itemId',
                                                                  isEqualTo:
                                                                      itemId,
                                                                )
                                                                .where(
                                                                  'requesterId',
                                                                  isEqualTo:
                                                                      requesterId,
                                                                )
                                                                .get();
                                                        if (existing
                                                            .docs
                                                            .isNotEmpty) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Order already exists',
                                                              ),
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        await reqRef.add({
                                                          'itemId': itemId,
                                                          'itemName': name,
                                                          'requesterId':
                                                              requesterId,
                                                          'requesterEmail':
                                                              requesterEmail,
                                                          'ownerId': ownerId,
                                                          'status': 'pending',
                                                          'timestamp':
                                                              FieldValue.serverTimestamp(),
                                                        });

                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Order placed',
                                                            ),
                                                          ),
                                                        );
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Order error: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                              child: const Text(
                                                'Place Order',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 0),
                                    // Status label
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('requests')
                                          .where(
                                            'requesterId',
                                            isEqualTo: userId,
                                          )
                                          .where(
                                            'itemId',
                                            isEqualTo:
                                                cartItem['itemId']
                                                    ?.toString() ??
                                                '',
                                          )
                                          .snapshots(),
                                      builder: (context, rs) {
                                        if (!rs.hasData ||
                                            rs.data!.docs.isEmpty)
                                          return const SizedBox.shrink();
                                        final r = rs.data!.docs.first;
                                        final st = (r['status'] ?? 'pending')
                                            .toString();
                                        String label = '';
                                        Color color = Colors.orange;
                                        if (st == 'pending') {
                                          label = '🟡 Order pending';
                                          color = Colors.orange;
                                        } else if (st == 'accepted') {
                                          label = '🟢 Order accepted';
                                          color = Colors.green;
                                        } else if (st == 'rejected') {
                                          label = '🔴 Order rejected';
                                          color = Colors.red;
                                        }

                                        // If accepted, show call and message actions next to the label.
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (st == 'accepted') ...[
                                              const SizedBox(width: 0),
                                              // Fetch owner details to get phone and name
                                              FutureBuilder<DocumentSnapshot?>(
                                                future: ownerId.isNotEmpty
                                                    ? FirebaseFirestore.instance.collection('users').doc(ownerId).get()
                                                    : Future.value(null),
                                                builder: (context, ownerSnap) {
                                                  final ownerData = (ownerSnap.hasData && ownerSnap.data != null && ownerSnap.data!.exists)
                                                      ? (ownerSnap.data!.data() as Map<String, dynamic>?) ?? {}
                                                      : <String, dynamic>{};
                                                  final ownerPhone = (ownerData['phone'] ?? '').toString();
                                                  final ownerName = (ownerData['name'] ?? '').toString();

                                                  return Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.call, color: Colors.green, size: 12),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(
                                                          minWidth: 16,
                                                          minHeight: 16,
                                                        ),
                                                        onPressed: ownerPhone.isNotEmpty
                                                            ? () async {
                                                                final uri = Uri(scheme: 'tel', path: ownerPhone);
                                                                try {
                                                                  if (await canLaunchUrl(uri)) {
                                                                    await launchUrl(uri);
                                                                  } else {
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                      const SnackBar(content: Text('Cannot open dialer')),
                                                                    );
                                                                  }
                                                                } catch (e) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(content: Text('Call error: $e')),
                                                                  );
                                                                }
                                                              }
                                                            : null,
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.message, color: Color(0xFF507B7B), size: 12),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(
                                                          minWidth: 16,
                                                          minHeight: 16,
                                                        ),
                                                        onPressed: ownerId.isNotEmpty
                                                            ? () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => ChatScreen(
                                                                      otherUserId: ownerId,
                                                                      otherUserName: ownerName.isNotEmpty ? ownerName : ownerId,
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            : null,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Checkout bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '₹${grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF507B7B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            // Placeholder checkout action
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Proceeding to checkout — total ₹${grandTotal.toStringAsFixed(2)}',
                                ),
                              ),
                            );
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
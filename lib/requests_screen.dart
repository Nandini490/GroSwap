import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  // Function to handle the update logic
  Future<void> _updateRequestStatus(
    String docId,
    String status,
    BuildContext context,
  ) async {
    await FirebaseFirestore.instance
        .collection('requests')
        .doc(docId)
        .update({'status': status});
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request $status'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          backgroundColor: const Color(0xFF507B7B),
        ),
        body: const Center(child: Text('Not signed in')),
      );
    }

    final userId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: const Color(0xFF507B7B),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('ownerId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF507B7B)),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No incoming requests'));
          }

          // Sort by timestamp desc client-side (documents may have null ts briefly)
          docs.sort((a, b) {
            final aTs = a['timestamp'] is Timestamp
                ? (a['timestamp'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final bTs = b['timestamp'] is Timestamp
                ? (b['timestamp'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return bTs.compareTo(aTs);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = (d.data() as Map<String, dynamic>?) ?? {};
              final requesterEmail = (data['requesterEmail'] ?? '').toString();
              final requesterName = (data['requesterName'] ?? '').toString();
              // requesterId available in data if needed
              final itemName = (data['itemName'] ?? 'Item').toString();
              final status = (data['status'] ?? 'pending').toString();
              final itemId = (data['itemId'] ?? '').toString();

              Color statusColor;
              if (status == 'accepted') {
                statusColor = Colors.green;
              } else if (status == 'rejected') {
                statusColor = Colors.red;
              } else {
                statusColor = Colors.orange;
              }

              // Fetch the referenced item to show images (non-blocking UI)
              return FutureBuilder<DocumentSnapshot?>(
                future: itemId.isNotEmpty
                    ? FirebaseFirestore.instance
                        .collection('items')
                        .doc(itemId)
                        .get()
                    : Future.value(null),
                builder: (context, itemSnap) {
                  final itemData = (itemSnap.hasData &&
                          itemSnap.data != null &&
                          itemSnap.data!.exists)
                      ? (itemSnap.data!.data() as Map<String, dynamic>?) ?? {}
                      : <String, dynamic>{};

                  final imageUrls =
                      ((itemData['imageUrls'] as List<dynamic>?) ?? <dynamic>[])
                          .map((e) => e.toString())
                          .where((s) => s.isNotEmpty)
                          .toList();
                  final fallbackImage = (itemData['imageUrl'] ?? '').toString();
                  final displayImages = imageUrls.isNotEmpty
                      ? imageUrls
                      : (fallbackImage.isNotEmpty
                          ? [fallbackImage]
                          : <String>[]);

                  // *** START OF LAYOUT MODIFICATION ***
                  // Use a custom structure instead of ListTile for better control
                  // over image and button layout.
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Item Images (Left Side)
                          SizedBox(
                            width: 60, // Reduced width for better layout
                            height: 60,
                            child: displayImages.isNotEmpty
                                ? ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        displayImages.length > 3 ? 3 : displayImages.length,
                                    itemBuilder: (context, i) {
                                      final url = displayImages[i];
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          url,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 6),
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                      size: 30,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Request Details (Center)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  itemName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'From: ${requesterName.isNotEmpty ? requesterName : requesterEmail}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Status/Action Buttons (Right Side)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (status == 'pending') ...[
                                SizedBox(
                                  width: 90, // Set fixed width for alignment
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => _updateRequestStatus(
                                        d.id, 'accepted', context),
                                    child: const Text('Accept'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 90, // Set fixed width for alignment
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => _updateRequestStatus(
                                        d.id, 'rejected', context),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                  // *** END OF LAYOUT MODIFICATION ***
                },
              );
            },
          );
        },
      ),
    );
  }
}
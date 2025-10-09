import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

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
              // requesterId available in data if needed
              final itemName = (data['itemName'] ?? 'Item').toString();
              final status = (data['status'] ?? 'pending').toString();

              Color statusColor;
              if (status == 'accepted')
                statusColor = Colors.green;
              else if (status == 'rejected')
                statusColor = Colors.red;
              else
                statusColor = Colors.orange;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(
                    itemName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('From: $requesterEmail'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'pending') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('requests')
                                .doc(d.id)
                                .update({'status': 'accepted'});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Request accepted')),
                            );
                          },
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('requests')
                                .doc(d.id)
                                .update({'status': 'rejected'});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Request rejected')),
                            );
                          },
                          child: const Text('Reject'),
                        ),
                      ] else ...[
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
}

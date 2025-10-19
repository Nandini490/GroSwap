import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:groswap/chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF507B7B),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00796B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messages')
              .where('participants', arrayContains: userId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              );
            }

            // Group messages by chatId (which may include itemId)
            final Map<String, Map<String, dynamic>> latestByChat = {};

            for (var d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final chatId = (data['chatId'] ?? '') as String;
              final ts = data['timestamp'] as Timestamp?;
              final current = latestByChat[chatId];
              if (current == null ||
                  (current['timestamp'] as Timestamp?)?.compareTo(
                        ts ?? Timestamp.now(),
                      ) ==
                      -1) {
                latestByChat[chatId] = {
                  'doc': d,
                  'timestamp': ts,
                  'itemId': data['itemId'] ?? '',
                };
              }
            }

            final entries = latestByChat.values.toList()
              ..sort((a, b) {
                final ta = a['timestamp'] as Timestamp?;
                final tb = b['timestamp'] as Timestamp?;
                return (tb ?? Timestamp.now()).compareTo(ta ?? Timestamp.now());
              });

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final d = entry['doc'] as QueryDocumentSnapshot;
                final data = d.data() as Map<String, dynamic>;
                final participants =
                    (data['participants'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [];
                final otherUser = participants.firstWhere(
                  (id) => id != userId,
                  orElse: () => 'Unknown',
                );
                final preview = (data['messageText'] ?? '').toString();
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final itemId = (data['itemId'] ?? '').toString();

                return Card(
                  color: Colors.black.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.message,
                      color: Color(0xFF80CBC4),
                    ),
                    title: Text(
                      'Chat with $otherUser',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      preview,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (timestamp != null)
                          Text(
                            '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: otherUser,
                            otherUserName: otherUser,
                            itemId: itemId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

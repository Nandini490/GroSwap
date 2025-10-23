import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) return (doc.data()?['name'] ?? 'Unknown User').toString();
    } catch (_) {}
    return 'Unknown User';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) return DateFormat.jm().format(timestamp); // e.g., 2:45 PM
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(timestamp); // e.g., Mon
    return DateFormat('dd/MM/yy').format(timestamp); // e.g., 19/10/25
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppTheme.warmBeige,
        centerTitle: true,
      ),
      body: Container(
        color: AppTheme.warmBeige,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messages')
              .where('participants', arrayContains: currentUserId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Group messages by chatId → latest message only
            final Map<String, QueryDocumentSnapshot> latestByChat = {};
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final chatId = (data['chatId'] ?? '').toString();
              if (chatId.isEmpty) continue;

              final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final existing = latestByChat[chatId];
              final existingTs = (existing?.get('timestamp') as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

              if (existing == null || ts.isAfter(existingTs)) {
                latestByChat[chatId] = doc;
              }
            }

            final chats = latestByChat.values.toList()
              ..sort((a, b) {
                final tsA = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final tsB = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                return tsB.compareTo(tsA);
              });

            if (chats.isEmpty) {
              return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.black54, fontSize: 16)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final doc = chats[index];
                final data = doc.data() as Map<String, dynamic>;
                final participants = (data['participants'] as List?)?.cast<String>() ?? [];
                final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => 'Unknown');
                final itemId = (data['itemId'] ?? '').toString();
                final preview = (data['messageText'] ?? '').toString();
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

                // Safe readBy handling
                final readBy = (data['readBy'] as List?)?.cast<String>() ?? [];
                final isUnread = !readBy.contains(currentUserId);

                return FutureBuilder<String>(
                  future: _getUserName(otherUserId),
                  builder: (context, snap) {
                    final otherUserName = snap.data ?? 'User';

                    // Conversation card: use a solid medium/dark brown so it's not blurry/light
                    final unreadCount = (data['unreadCount'] as int?) ?? (isUnread ? 1 : 0);
                    return Card(
                      color: AppTheme.mediumBrown.withOpacity(0.95),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppTheme.terracotta.withOpacity(0.18),
                              child: Text(
                                otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            if (isUnread)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  otherUserName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w700,
                    fontSize: 16),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.terracotta,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                        ),
                        trailing: timestamp != null
                            ? Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              )
                            : null,
                        onTap: () async {
                          // Mark messages as read
                          final messagesRef = FirebaseFirestore.instance.collection('messages');
                          final chatId = (data['chatId'] ?? '').toString();

                          final unreadMessages = await messagesRef.where('chatId', isEqualTo: chatId).get();

                          for (var msg in unreadMessages.docs) {
                            final msgData = msg.data() as Map<String, dynamic>;
                            final readList = (msgData['readBy'] as List?)?.cast<String>() ?? [];
                            if (!readList.contains(currentUserId)) {
                              await msg.reference.update({
                                'readBy': FieldValue.arrayUnion([currentUserId])
                              });
                            }
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: otherUserId,
                                otherUserName: otherUserName,
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
            );
          },
        ),
      ),
    );
  }
}

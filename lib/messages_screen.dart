import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }

        final messages = snapshot.data!.docs;

        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final otherUser = (msg['participants'] as List).firstWhere((id) => id != userId);
            return ListTile(
              leading: const Icon(Icons.message, color: Colors.teal),
              title: Text('Chat with $otherUser', style: const TextStyle(color: Colors.white)),
              subtitle: Text(msg['messageText'], style: const TextStyle(color: Colors.grey)),
            );
          },
        );
      },
    );
  }
}

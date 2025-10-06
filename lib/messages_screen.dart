import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
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

            final messages = snapshot.data!.docs;

            if (messages.isEmpty) {
              return const Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final otherUser = (msg['participants'] as List)
                    .firstWhere((id) => id != userId);

                return Card(
                  color: Colors.black.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.message, color: Color(0xFF80CBC4)),
                    title: Text(
                      'Chat with $otherUser',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      msg['messageText'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
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

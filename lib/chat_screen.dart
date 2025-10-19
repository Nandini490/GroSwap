import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _me;

  String get _chatId {
    // deterministic room id for two participants
    if (_me == null) return '';
    final ids = [_me!, widget.otherUserId]..sort();
    return ids.join('_');
  }

  CollectionReference get _messagesRef =>
      FirebaseFirestore.instance.collection('messages');

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_me == null) return;
    final doc = _messagesRef.doc();
    await doc.set({
      'id': doc.id,
      'chatId': _chatId,
      'participants': [_me, widget.otherUserId],
      'senderId': _me,
      'messageText': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _controller.clear();
    // scroll to bottom after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If not authenticated, close the screen to avoid hanging in a loader
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _me = user.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user is not available yet, show a friendly message instead of building queries
    if (_me == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Chat with ${widget.otherUserName}'),
          backgroundColor: const Color(0xFF507B7B),
          centerTitle: true,
        ),
        body: const Center(child: Text('Please sign in to use chat')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.otherUserName}'),
        backgroundColor: const Color(0xFF507B7B),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef
                  .where('chatId', isEqualTo: _chatId)
                  .snapshots(),
              builder: (context, snap) {
                // If still waiting for the first snapshot, do not show an indefinite spinner.
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Text('Start the conversation'));
                }

                if (snap.hasError) {
                  return Center(
                      child: Text('Chat error: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final sortedDocs = docs..sort((a, b) {
                  final tsA = a['timestamp'] as Timestamp?;
                  final tsB = b['timestamp'] as Timestamp?;
                  return (tsA?.compareTo(tsB ?? Timestamp.now()) ?? 0).compareTo(
                    (tsB?.compareTo(tsA ?? Timestamp.now()) ?? 0)
                  );
                });
                if (sortedDocs.isEmpty) {
                  return const Center(child: Text('Start the conversation'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final m = sortedDocs[index];
                    final sender = (m['senderId'] ?? '').toString();
                    final text = (m['messageText'] ?? '').toString();
                    final mine = sender == _me;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF507B7B)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: mine ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF507B7B),
                    ),
                    onPressed: _sendMessage,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
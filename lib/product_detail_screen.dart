import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProductDetailScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const ProductDetailScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _pageIndex = 0;
  bool _adding = false;
  bool _added = false;

  List<String> get _images {
    final list =
        ((widget.itemData['imageUrls'] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
    final fallback = (widget.itemData['imageUrl'] ?? '').toString();
    if (list.isEmpty && fallback.isNotEmpty) return [fallback];
    if (list.isEmpty) return [];
    return list;
  }

  @override
  void initState() {
    super.initState();
    _checkInCart();
  }

  Future<void> _checkInCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final existing = await FirebaseFirestore.instance
        .collection('cart')
        .where('userId', isEqualTo: user.uid)
        .where('itemId', isEqualTo: widget.itemId)
        .get();
    if (mounted) setState(() => _added = existing.docs.isNotEmpty);
  }

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _adding = true);
    try {
      final cartRef = FirebaseFirestore.instance.collection('cart');
      final existing = await cartRef
          .where('userId', isEqualTo: user.uid)
          .where('itemId', isEqualTo: widget.itemId)
          .get();
      if (existing.docs.isNotEmpty) {
        if (mounted) setState(() => _added = true);
      } else {
        await cartRef.add({
          'userId': user.uid,
          'itemId': widget.itemId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _added = true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cart error: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _buildCarousel(BuildContext context) {
    final images = _images;
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset('assets/images/placeholder.jpg', fit: BoxFit.cover),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, i) {
              final url = images[i];
              return Hero(
                tag: 'product_${widget.itemId}_$i',
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, prog) {
                    if (prog == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, _, __) => Image.asset(
                    'assets/images/placeholder.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _pageIndex == i ? 10 : 6,
                  height: _pageIndex == i ? 10 : 6,
                  decoration: BoxDecoration(
                    color: _pageIndex == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.itemData;
    final name = (data['name'] ?? 'Unnamed').toString();
    final desc = (data['notes'] ?? '').toString();
    final price = (data['price'] ?? 0).toString();
    final rating = (data['rating'] ?? 0).toString();
    final stock = (data['quantity'] ?? 'N/A').toString();
    DateTime? expiry;
    if (data['expiryDate'] != null && data['expiryDate'] is Timestamp)
      expiry = (data['expiryDate'] as Timestamp).toDate();

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color(0xFF507B7B),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _buildCarousel(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildDetails(
                            name,
                            desc,
                            price,
                            rating,
                            stock,
                            expiry,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCarousel(context),
                        const SizedBox(height: 12),
                        _buildDetails(name, desc, price, rating, stock, expiry),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetails(
    String name,
    String desc,
    String price,
    String rating,
    String stock,
    DateTime? expiry,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '₹$price',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF507B7B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            Text(rating),
            const SizedBox(width: 12),
            Text('Stock: $stock'),
            const SizedBox(width: 12),
            if (expiry != null)
              Text('Expiry: ${expiry.toLocal().toString().split(' ')[0]}'),
          ],
        ),
        const SizedBox(height: 12),
        Text(desc),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: _adding || _added ? null : _addToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF507B7B),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            ),
            child: _adding
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(_added ? 'Added to Cart' : 'Add to Cart'),
          ),
        ),
      ],
    );
  }
}

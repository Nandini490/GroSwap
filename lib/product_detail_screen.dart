import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

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
  late final PageController _pageController;

  List<String> get _images {
    // Prefer `images`, then `imageUrls`, then `imageUrl` fallback.
    final fromImages =
        ((widget.itemData['images'] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
    if (fromImages.isNotEmpty) return fromImages;

    final list =
        ((widget.itemData['imageUrls'] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
    if (list.isNotEmpty) return list;

    final fallback = (widget.itemData['imageUrl'] ?? '').toString();
    if (fallback.isNotEmpty) return [fallback];
    return [];
  }

  // If itemData didn't contain imageUrls, try fetching the latest from Firestore
  // (useful if the detail screen was opened with stale/minimal data).
  Future<List<String>> _fetchImageUrlsFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .get();
      if (!doc.exists) return [];
      final data = doc.data();
      if (data == null) return [];
      final list = ((data['imageUrls'] as List<dynamic>?) ?? <dynamic>[])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      return list;
    } catch (e) {
      if (kDebugMode) print('image fetch error: $e');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _checkInCart();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    // Use FutureBuilder so we can fall back to fetching from Firestore if
    // the provided itemData didn't include images.
    return FutureBuilder<List<String>>(
      future: Future.value(_images).then((local) async {
        if (local.isNotEmpty) return local;
        return await _fetchImageUrlsFromFirestore();
      }),
      builder: (context, snap) {
        final images = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (images.isEmpty) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: Text('No images available')),
          );
        }

        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Column(
            children: [
              Expanded(
                child: CarouselSlider.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index, realIdx) {
                    final url = images[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 6.0,
                      ),
                      child: Hero(
                        tag: 'product_${widget.itemId}_$index',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, prog) {
                              if (prog == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, _, __) => Image.asset(
                              'assets/images/placeholder.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  options: CarouselOptions(
                    viewportFraction: 1.0,
                    enlargeCenterPage: false,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration: const Duration(
                      milliseconds: 800,
                    ),
                    pauseAutoPlayOnTouch: true,
                    enableInfiniteScroll: images.length > 1,
                    onPageChanged: (idx, reason) =>
                        setState(() => _pageIndex = idx),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
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
            ],
          ),
        );
      },
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

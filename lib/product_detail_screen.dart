import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:async';

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

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  int _pageIndex = 0;
  late PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentImageCount = 0;
  int? _pendingPage;
  bool _adding = false;
  bool _added = false;
  bool _wishlisted = false;
  late final TabController _tabController;

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
    _tabController = TabController(length: 4, vsync: this);
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_currentImageCount <= 1) return;
      final next = (_pageIndex + 1) % _currentImageCount;
      if (_pageController.hasClients) {
        _pageController.animateToPage(next,
            duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  void _animateToPage(int page) {
    // Try animate immediately; if controller not attached yet, schedule for next frame
    try {
      if (_pageController.hasClients) {
        try {
          _pageController.animateToPage(page,
              duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        } catch (_) {
          try {
            _pageController.jumpToPage(page);
          } catch (_) {}
        }
        if (kDebugMode) print('navigated to page $page (animate)');
        setState(() => _pageIndex = page);
        return;
      }
    } catch (_) {}
    // If controller has no clients yet, replace it with a controller set to target page
    try {
      final old = _pageController;
      _pageController = PageController(initialPage: page);
      try {
        old.dispose();
      } catch (_) {}
      if (mounted) setState(() => _pageIndex = page);
      if (kDebugMode) print('replaced page controller and set page $page');
      return;
    } catch (_) {
      // last fallback: schedule post frame to try again
      _pendingPage = page;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pendingPage == null) return;
        try {
          if (_pageController.hasClients) {
            try {
              _pageController.animateToPage(_pendingPage!,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } catch (_) {
              try {
                _pageController.jumpToPage(_pendingPage!);
              } catch (_) {}
            }
            if (kDebugMode) print('navigated to pending page ${_pendingPage!}');
            _pendingPage = null;
          }
        } catch (_) {}
      });
    }
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
    // Use FutureBuilder to use local images or fall back to Firestore
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

        // update internal count after build
        if (_currentImageCount != images.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentImageCount = images.length);
          });
        }

        // Pre-build arrow widgets to avoid complex inline expressions
        final leftArrow = images.length > 1
            ? Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InkWell(
                    onTap: () {
                      final prev = (_pageIndex - 1) < 0 ? images.length - 1 : _pageIndex - 1;
                      _animateToPage(prev);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();

        final rightArrow = images.length > 1
            ? Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InkWell(
                    onTap: () {
                      final next = (_pageIndex + 1) % images.length;
                      _animateToPage(next);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();

        final dots = Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _pageIndex == i ? 12 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _pageIndex == i ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        );

        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                itemCount: images.length,
                onPageChanged: (idx) => setState(() => _pageIndex = idx),
                itemBuilder: (context, index) {
                  final url = images[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Hero(
                      tag: 'product_${widget.itemId}_$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.network(
                            url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, prog) {
                              if (prog == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, _, __) => Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              leftArrow,
              rightArrow,
              dots,
            ],
          ),
        );
      },
    );
  }

  void _copyShareLink() {
    final link =
        widget.itemData['link'] ?? 'https://example.com/item/${widget.itemId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product link copied to clipboard')),
    );
  }

  // left/right arrow helpers removed; inline arrows are built inside _buildCarousel

  @override
  Widget build(BuildContext context) {
    final data = widget.itemData;
    final name = (data['name'] ?? 'Unnamed').toString();
    final desc = (data['notes'] ?? '').toString();
    final price = (data['price'] ?? 0).toString();
    final rating = (data['rating'] ?? 0).toString();
    final stock = (data['quantity'] ?? 'N/A').toString();
    final sellerRaw =
        (data['seller'] ??
                data['userEmail'] ??
                data['userId'] ??
                'Resourcely Store')
            .toString();
    final seller = sellerRaw.contains('@')
        ? sellerRaw.split('@')[0]
        : sellerRaw;
  final discountPercent = data['discountPercent'] ?? 0;
    // expiry is displayed in the description tab (if present)

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carousel
              _buildCarousel(context),
              const SizedBox(height: 12),

              // Title & badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (discountPercent != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF3B30)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Rating and stock
              Row(
                children: [
                  _buildRatingRow(rating),
                  const SizedBox(width: 12),
                  const Spacer(),
                  Chip(
                    backgroundColor: stock == '0'
                        ? Colors.red[50]
                        : Colors.green[50],
                    label: Text(stock == '0' ? 'Out of stock' : 'In stock'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Price below rating
              Text(
                '₹$price',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),

              // Seller info & actions
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Sold by ',
                        style: const TextStyle(color: Colors.black54),
                        children: [
                          TextSpan(
                            text: seller,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _wishlisted = !_wishlisted),
                    icon: Icon(
                      _wishlisted ? Icons.favorite : Icons.favorite_border,
                      color: _wishlisted ? Colors.red : Colors.black54,
                    ),
                  ),
                  IconButton(
                    onPressed: _copyShareLink,
                    icon: const Icon(Icons.share, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Add to cart button (no quantity selector, no Buy Now)
              Row(
                children: [
                  Expanded(
                    child: _adding
                        ? Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _buildGradientButton(
                            _added ? 'Added to Cart' : 'Add to Cart',
                            () async {
                              if (stock == '0') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Out of stock')),
                                );
                                return;
                              }
                              await _addToCart();
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to cart'),
                                  ),
                                );
                            },
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: AppTheme.terracotta,
                      tabs: const [
                        Tab(text: 'Description'),
                        Tab(text: 'Specifications'),
                        Tab(text: 'Reviews'),
                        Tab(text: 'Related'),
                      ],
                    ),
                    SizedBox(
                      height: 360,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDescription(desc),
                          _buildSpecifications(data),
                          _buildReviews(),
                          _buildRelatedProducts(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingRow(String ratingStr) {
    // Hide rating if it's '0' or empty
    if (ratingStr.trim().isEmpty) return const SizedBox.shrink();
    final numeric = double.tryParse(ratingStr) ?? 0.0;
    if (numeric <= 0) return const SizedBox.shrink();
    // Show rating number only (no star icons)
    return Row(
      children: [
        Text(ratingStr, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildGradientButton(
    String label,
    VoidCallback onTap, {
    bool accent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: accent
                ? [Colors.deepOrange, Colors.orange]
                : [AppTheme.terracotta, const Color(0xFF2F6F6F)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(String desc) {
    final data = widget.itemData;
    final category = (data['category'] ?? data['type'] ?? 'N/A').toString();
    final condition = (data['condition'] ?? 'N/A').toString();
    final purpose = (data['purpose'] ?? 'N/A').toString();
    final unit = (data['unit'] ?? 'N/A').toString();
    final quantity = (data['quantity'] ?? 'N/A').toString();
    final location = (data['location'] ?? 'N/A').toString();
    String expiryText = '';
    if (data['expiryDate'] != null && data['expiryDate'] is Timestamp) {
      expiryText = (data['expiryDate'] as Timestamp)
          .toDate()
          .toLocal()
          .toString()
          .split(' ')[0];
    }
    final notes = (data['notes'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[Text(desc), const SizedBox(height: 12)],
          Text(
            'Category: $category',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Condition: $condition',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Purpose: $purpose',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Quantity: $quantity',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text('Unit: $unit', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 6),
          Text(
            'Location: $location',
            style: const TextStyle(color: Colors.black87),
          ),
          if (expiryText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Expiry: $expiryText',
              style: const TextStyle(color: Colors.black87),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Seller notes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(notes),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecifications(Map<String, dynamic> data) {
    final rawSpecs = (data['specs'] as Map<String, dynamic>?) ?? {};
    final specs = Map<String, dynamic>.from(rawSpecs);
    // Fallback to a few top-level fields if specs is empty
    if (specs.isEmpty) {
      if (data['brand'] != null) specs['Brand'] = data['brand'];
      if (data['weight'] != null) specs['Weight'] = data['weight'];
      if (data['dimensions'] != null) specs['Dimensions'] = data['dimensions'];
      if (data['condition'] != null) specs['Condition'] = data['condition'];
      if (data['type'] != null) specs['Type'] = data['type'];
      if (data['category'] != null) specs['Category'] = data['category'];
    }

    if (specs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('No specifications available.'),
      );
    }

    IconData _iconForKey(String key) {
      final k = key.toLowerCase();
      if (k.contains('brand') || k.contains('seller')) return Icons.store;
      if (k.contains('size')) return Icons.straighten;
      if (k.contains('color')) return Icons.color_lens;
      if (k.contains('material')) return Icons.layers;
      if (k.contains('model') || k.contains('model')) return Icons.devices;
      if (k.contains('processor') || k.contains('ram') || k.contains('storage'))
        return Icons.memory;
      if (k.contains('warranty')) return Icons.shield;
      if (k.contains('author') || k.contains('publisher')) return Icons.person;
      if (k.contains('expiry') ||
          k.contains('expirydate') ||
          k.contains('expiry date'))
        return Icons.event;
      if (k.contains('weight')) return Icons.scale;
      if (k.contains('battery')) return Icons.battery_full;
      return Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: specs.entries.map((e) {
          final key = e.key.toString();
          final rawVal = e.value;
          final value = rawVal is Timestamp
              ? rawVal.toDate().toLocal().toString().split(' ')[0]
              : rawVal is DateTime
              ? rawVal.toLocal().toString().split(' ')[0]
              : rawVal.toString();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[100],
                    child: Icon(
                      _iconForKey(key),
                      size: 18,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          key,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviews() {
    final List<Map<String, Object>> reviews = [
      {
        'name': 'Anita',
        'rating': 5,
        'text': 'Great product! Highly recommend.',
      },
      {'name': 'Raj', 'rating': 4, 'text': 'Good value for money.'},
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: reviews.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, i) {
        final r = reviews[i];
        final String name = (r['name'] as String?) ?? 'User';
        final int rating = (r['rating'] as int?) ?? 0;
        final String text = (r['text'] as String?) ?? '';
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
          title: Row(
            children: [
              Text(name),
              const SizedBox(width: 8),
              Row(
                children: List.generate(
                  rating,
                  (i) => const Icon(Icons.star, color: Colors.amber, size: 14),
                ),
              ),
            ],
          ),
          subtitle: Text(text),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
    );
  }

  Widget _buildRelatedProducts() {
    final related = List.generate(
      6,
      (i) => {'name': 'Related $i', 'price': (100 + i * 20), 'image': null},
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: CarouselSlider.builder(
        itemCount: related.length,
        itemBuilder: (context, index, realIdx) {
          final item = related[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${(item['price'] ?? 0).toString()}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        options: CarouselOptions(
          height: 220,
          enlargeCenterPage: false,
          enableInfiniteScroll: false,
          viewportFraction: 0.45,
        ),
      ),
    );
  }
}

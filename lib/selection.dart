import 'package:flutter/material.dart';
import 'home_screen.dart';

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  void selectCategory(BuildContext context, String category) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(selectedCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Category> categories = [
      Category(
          name: "Apartment",
          colors: [Colors.blue.shade400, Colors.blue.shade900],
          icon: Icons.apartment),
      Category(
          name: "Hostel",
          colors: [Colors.green.shade400, Colors.green.shade900],
          icon: Icons.house),
      Category(
          name: "College",
          colors: [Colors.orange.shade400, Colors.orange.shade900],
          icon: Icons.school),
      Category(
          name: "Students",
          colors: [Colors.purple.shade400, Colors.purple.shade900],
          icon: Icons.person),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.teal.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                double width = constraints.maxWidth;

                if (width >= 1200) {
                  crossAxisCount = 4;
                } else if (width >= 800) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  itemCount: categories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return HoverableCard(
                      category: category,
                      onTap: () => selectCategory(context, category.name),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class HoverableCard extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;
  const HoverableCard({super.key, required this.category, required this.onTap});

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()
            ..scale(_isHovered ? 1.05 : (_isPressed ? 0.95 : 1.0)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.category.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.category.colors.last.withOpacity(_isHovered ? 0.7 : 0.5),
                offset: const Offset(0, 6),
                blurRadius: _isHovered ? 12 : 8,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.category.icon, size: 50, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(1, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Category {
  final String name;
  final List<Color> colors;
  final IconData icon;

  Category({required this.name, required this.colors, required this.icon});
}

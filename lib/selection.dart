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
      Category(name: "Apartment", color: Colors.blue, icon: Icons.apartment),
      Category(name: "Hostel", color: Colors.green, icon: Icons.house),
      Category(name: "College", color: Colors.orange, icon: Icons.school),
      Category(name: "Students", color: Colors.purple, icon: Icons.person),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Select Your Category")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine number of columns based on screen width
            int crossAxisCount = 2; // default for mobile
            double width = constraints.maxWidth;

            if (width >= 1200) {
              crossAxisCount = 4; // desktop
            } else if (width >= 800) {
              crossAxisCount = 3; // tablet
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
                return GestureDetector(
                  onTap: () => selectCategory(context, category.name),
                  child: Card(
                    color: category.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            category.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

// Strongly typed category class
class Category {
  final String name;
  final Color color;
  final IconData icon;

  Category({required this.name, required this.color, required this.icon});
}

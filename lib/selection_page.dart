import 'package:flutter/material.dart';
import 'home_feed.dart'; // Ensure this path matches your HomeFeed.dart location

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // List of community types
    final List<Map<String, dynamic>> communities = [
      {'name': 'Hostel', 'icon': Icons.school},
      {'name': 'Apartment', 'icon': Icons.apartment},
      {'name': 'PG', 'icon': Icons.home_work},
      {'name': 'University / College', 'icon': Icons.account_balance},
      {'name': 'Retailer / Vendor', 'icon': Icons.store},
    ];

    final size = MediaQuery.of(context).size;
    final double cardHeight = size.height * 0.2; // responsive card height

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Select Your Community'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: communities.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // two cards per row
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1, // square cards
          ),
          itemBuilder: (context, index) {
            final community = communities[index];
            return GestureDetector(
              onTap: () {
                // Navigate to HomeFeed for the selected community
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HomeFeed(community: community['name']),
                  ),
                );
              },
              child: Card(
                color: Colors.teal.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(community['icon'], size: 50, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        community['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

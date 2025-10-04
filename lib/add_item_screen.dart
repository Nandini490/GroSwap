import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String selectedCategory = 'Grocery';
  String selectedCondition = 'New';
  String selectedPurpose = 'Sell';
  DateTime? _selectedExpiryDate;
  File? _selectedImage;
  bool _isLoading = false;

  // 🧠 Pick Image
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  // 🧠 Pick Expiry Date (for groceries)
  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedExpiryDate = picked);
    }
  }

  // 🧠 Save Item to Firestore
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? imageUrl;

      // Upload image to Firebase Storage
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('item_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('items').add({
        'userId': user.uid,
        'userEmail': user.email,
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'category': selectedCategory,
        'condition': selectedCondition,
        'purpose': selectedPurpose,
        'quantity': _quantityController.text.trim(),
        'unit': _unitController.text.trim(),
        'location': _locationController.text.trim(),
        'notes': _notesController.text.trim(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        if (selectedCategory == 'Grocery' && _selectedExpiryDate != null)
          'expiryDate': _selectedExpiryDate,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item added successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Item"),
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: _selectedImage == null
                      ? Container(
                          height: 160,
                          width: double.infinity,
                          color: Colors.teal.withOpacity(0.15),
                          child: const Center(
                            child: Icon(Icons.add_a_photo,
                                size: 50, color: Colors.teal),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedImage!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover),
                        ),
                ),
                const SizedBox(height: 16),

                // 🏷️ Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Item Name",
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter item name' : null,
                ),
                const SizedBox(height: 12),

                // 💰 Price
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: "Price",
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter item price' : null,
                ),
                const SizedBox(height: 12),

                // 🗂️ Category
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: "Category",
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Grocery',
                    'Gadgets',
                    'Stationery',
                    'Books',
                    'Electronics',
                    'Clothing'
                  ]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value!;
                      _selectedExpiryDate = null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // ⚙️ Condition
                DropdownButtonFormField<String>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: "Condition",
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: ['New', 'Like New', 'Used', 'Needs Repair']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedCondition = v!),
                ),
                const SizedBox(height: 12),

                // 🔁 Purpose
                DropdownButtonFormField<String>(
                  value: selectedPurpose,
                  decoration: const InputDecoration(
                    labelText: "Purpose",
                    prefixIcon: Icon(Icons.swap_horiz),
                    border: OutlineInputBorder(),
                  ),
                  items: ['Sell', 'Swap', 'Rent']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedPurpose = v!),
                ),
                const SizedBox(height: 12),

                // 🔢 Quantity & Unit
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: "Quantity",
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: "Unit (e.g. kg, pcs)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 📦 Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: "Storage Location (optional)",
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // 📝 Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Notes (optional)",
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // 📅 Expiry Date (only for groceries)
                if (selectedCategory == 'Grocery')
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _pickExpiryDate,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedExpiryDate == null
                            ? 'Select Expiry Date'
                            : 'Expiry: ${_selectedExpiryDate!.toLocal().toString().split(' ')[0]}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // 💾 Save
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : ElevatedButton(
                          onPressed: _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 60),
                          ),
                          child: const Text(
                            "Save Item",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
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

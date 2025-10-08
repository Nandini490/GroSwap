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

  // Pick Image from Gallery
  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (picked != null) {
        final file = File(picked.path);
        if (file.existsSync()) {
          setState(() => _selectedImage = file);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeImage() => setState(() => _selectedImage = null);

  // Pick Expiry Date
  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedExpiryDate = picked);
  }

  // Save Item to Firestore and MyList
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      String imageUrl = '';

      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('item_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      final data = {
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
      };

      if (selectedCategory == 'Grocery' && _selectedExpiryDate != null) {
        data['expiryDate'] = Timestamp.fromDate(_selectedExpiryDate!);
      }

      // Save item to 'items' collection
      final docRef = await FirebaseFirestore.instance.collection('items').add(data);

      // Automatically add item to 'mylist'
      await FirebaseFirestore.instance.collection('mylist').add({
        'userId': user.uid,
        'itemId': docRef.id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item added successfully!'),
            backgroundColor: Color(0xFF507B7B),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
      backgroundColor: const Color(0xFF507B7B),
      appBar: AppBar(
        title: const Text('Add Item', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: _selectedImage != null && _selectedImage!.existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 160,
                                    width: double.infinity,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image, size: 50),
                                  );
                                },
                              ),
                            )
                          : Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                              ),
                            ),
                    ),
                    if (_selectedImage != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: _removeImage,
                          child: const CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildTextField(_nameController, "Item Name", Icons.label),
                const SizedBox(height: 12),
                _buildTextField(_priceController, "Price", Icons.attach_money,
                    inputType: TextInputType.number),
                const SizedBox(height: 12),

                _buildDropdown(
                  label: "Category",
                  icon: Icons.category,
                  value: selectedCategory,
                  items: [
                    'Grocery',
                    'Gadgets',
                    'Stationery',
                    'Books',
                    'Electronics',
                    'Clothing'
                  ],
                  onChanged: (v) {
                    setState(() {
                      selectedCategory = v!;
                      _selectedExpiryDate = null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                _buildDropdown(
                  label: "Condition",
                  icon: Icons.inventory_2_outlined,
                  value: selectedCondition,
                  items: ['New', 'Like New', 'Used', 'Needs Repair'],
                  onChanged: (v) => setState(() => selectedCondition = v!),
                ),
                const SizedBox(height: 12),

                _buildDropdown(
                  label: "Purpose",
                  icon: Icons.swap_horiz,
                  value: selectedPurpose,
                  items: ['Sell', 'Swap', 'Rent'],
                  onChanged: (v) => setState(() => selectedPurpose = v!),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            _quantityController, "Quantity", Icons.numbers)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTextField(
                            _unitController, "Unit (kg, pcs...)", Icons.scale)),
                  ],
                ),
                const SizedBox(height: 12),

                _buildTextField(
                    _locationController, "Location (optional)", Icons.location_on_outlined),
                const SizedBox(height: 12),
                _buildTextField(
                    _notesController, "Notes (optional)", Icons.notes,
                    maxLines: 2),
                const SizedBox(height: 12),

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
                        backgroundColor: const Color(0xFF507B7B),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : ElevatedButton(
                          onPressed: _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF507B7B),
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

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon,
      {int maxLines = 1, TextInputType inputType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) => (v == null || v.isEmpty) && label.contains("optional")
          ? null
          : (v == null || v.isEmpty)
              ? 'Enter $label'
              : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: items
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(color: Colors.black87)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

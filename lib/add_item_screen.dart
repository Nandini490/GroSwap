import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? _uploadedImageUrl; // Store the uploaded Cloudinary URL
  bool _isLoading = false;
  bool _isUploadingImage = false; // Track image upload state

  // Cloudinary setup
  final cloudinary = CloudinaryPublic(
    'dsq93kxoa', // Your Cloudinary cloud name
    'resourcely_items', // Your upload preset
    cache: false,
  );

  // Pick image from gallery and upload immediately
  Future<void> _pickImage() async {
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied to access storage')),
          );
          return;
        }
      }

      // Pick image
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (file.existsSync()) {
          setState(() {
            _selectedImage = file;
            _isUploadingImage = true;
          });
          print("Selected image path: ${file.path}");

          // Upload to Cloudinary immediately
          await _uploadToCloudinary(file);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file does not exist')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      setState(() => _isUploadingImage = false);
    }
  }

  // Upload image to Cloudinary
  Future<void> _uploadToCloudinary(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'resourcely_items',
        ),
      );

      setState(() {
        _uploadedImageUrl = response.secureUrl;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image uploaded successfully!'),
            backgroundColor: Color(0xFF507B7B),
            duration: Duration(seconds: 2),
          ),
        );
      }

      print("Image uploaded to Cloudinary: $_uploadedImageUrl");
    } catch (e) {
      setState(() => _isUploadingImage = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print("Cloudinary upload error: $e");
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
    });
  }

  // Pick expiry date for grocery items
  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedExpiryDate = picked);
  }

  // Save item to Firestore with the uploaded image URL
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if image is still uploading
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for image upload to complete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

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
        'imageUrl': _uploadedImageUrl ?? '', // Use the pre-uploaded URL
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (selectedCategory == 'Grocery' && _selectedExpiryDate != null) {
        data['expiryDate'] = Timestamp.fromDate(_selectedExpiryDate!);
      }

      final docRef = await FirebaseFirestore.instance.collection('items').add(data);

      // Add item to 'mylist'
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
                // Image Picker with Upload Indicator
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingImage ? null : _pickImage,
                      child: _selectedImage != null && _selectedImage!.existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.file(
                                    _selectedImage!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  if (_isUploadingImage)
                                    Container(
                                      height: 160,
                                      width: double.infinity,
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Uploading...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
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
                                child: Icon(
                                  Icons.add_a_photo,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                    if (_selectedImage != null && !_isUploadingImage)
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
                    if (_uploadedImageUrl != null && !_isUploadingImage)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Uploaded',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                    'Clothing',
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
                _buildTextField(_locationController, "Location (optional)", Icons.location_on_outlined),
                const SizedBox(height: 12),
                _buildTextField(_notesController, "Notes (optional)", Icons.notes,
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
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
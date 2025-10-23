import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'profile_screen.dart' show MapPickerScreen;
import 'theme/app_theme.dart';

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
  LatLng? _pickedLocation;
  final _notesController = TextEditingController();

  // Rent-specific controllers
  final _rentalPriceController = TextEditingController();
  final _depositController = TextEditingController();
  final _minDurationController = TextEditingController();
  final _maxDurationController = TextEditingController();
  DateTime? _rentalStartDate;
  DateTime? _rentalEndDate;
  String selectedDurationUnit = 'Days';

  String selectedCategory = 'Grocery';
  String selectedCondition = 'New';
  String selectedPurpose = 'Sell';
  DateTime? _selectedExpiryDate;

  List<File> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  bool _isLoading = false;
  bool _isUploadingImage = false;
  Map<String, dynamic>? _specs;

  final cloudinary = CloudinaryPublic(
    'dsq93kxoa',
    'resourcely_unsigned',
    cache: false,
  );

  // Image pickers & upload
  Future<void> _pickImages() async {
    try {
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.storage.request();
        if (!status.isGranted) return;
      }

      final pickedFiles = await ImagePicker().pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (pickedFiles.isEmpty) return;

      setState(() => _isUploadingImage = true);

      for (final picked in pickedFiles) {
        final file = File(picked.path);
        if (!file.existsSync()) continue;
        setState(() => _selectedImages.add(file));
        final url = await _uploadToCloudinary(file);
        if (url != null) setState(() => _uploadedImageUrls.add(url));
      }

      setState(() => _isUploadingImage = false);
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    }
  }

  Future<void> _takePhoto() async {
    try {
      if (Platform.isAndroid) {
        PermissionStatus camStatus = await Permission.camera.request();
        if (!camStatus.isGranted) return;
      }

      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);
      final file = File(picked.path);
      if (!file.existsSync()) return;

      setState(() => _selectedImages.add(file));
      final url = await _uploadToCloudinary(file);
      if (url != null) setState(() => _uploadedImageUrls.add(url));
      setState(() => _isUploadingImage = false);
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error taking photo: $e')));
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'resourcely_items'),
      );
      return response.secureUrl;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      return null;
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index >= 0 && index < _selectedImages.length) _selectedImages.removeAt(index);
      if (index >= 0 && index < _uploadedImageUrls.length) _uploadedImageUrls.removeAt(index);
    });
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedExpiryDate = picked);
  }

  Future<void> _pickRentalStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _rentalStartDate = picked);
  }

  Future<void> _pickRentalEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rentalStartDate ?? DateTime.now(),
      firstDate: _rentalStartDate ?? DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _rentalEndDate = picked);
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingImage) return;

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
        'specs': _specs ?? {},
        'imageUrls': _uploadedImageUrls,
        'imageUrl': _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : '',
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_pickedLocation != null) {
        data['locationGeoPoint'] = GeoPoint(_pickedLocation!.latitude, _pickedLocation!.longitude);
      }

      if (selectedCategory == 'Grocery' && _selectedExpiryDate != null) {
        data['expiryDate'] = Timestamp.fromDate(_selectedExpiryDate!);
      }

      // Rent-specific data
      if (selectedPurpose == 'Rent') {
        data.addAll({
          'rentalPrice': double.tryParse(_rentalPriceController.text.trim()) ?? 0,
          'deposit': double.tryParse(_depositController.text.trim()) ?? 0,
          'minDuration': int.tryParse(_minDurationController.text.trim()) ?? 0,
          'maxDuration': int.tryParse(_maxDurationController.text.trim()) ?? 0,
          'durationUnit': selectedDurationUnit,
          'rentalStartDate': _rentalStartDate != null ? Timestamp.fromDate(_rentalStartDate!) : null,
          'rentalEndDate': _rentalEndDate != null ? Timestamp.fromDate(_rentalEndDate!) : null,
        });
      }

      final docRef = await FirebaseFirestore.instance.collection('items').add(data);
      await FirebaseFirestore.instance.collection('mylist').add({
        'userId': user.uid,
        'itemId': docRef.id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ Item added successfully!'), backgroundColor: AppTheme.terracotta),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
    _rentalPriceController.dispose();
    _depositController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBeige,
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
                // Images picker + preview row
                SizedBox(
                  height: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _selectedImages.isNotEmpty
                            ? ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, idx) {
                                  final f = _selectedImages[idx];
                                  final uploaded = idx < _uploadedImageUrls.length;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(f, width: 160, height: 160, fit: BoxFit.cover),
                                      ),
                                      if (!uploaded && _isUploadingImage)
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black45,
                                            child: const Center(
                                              child: CircularProgressIndicator(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () => _removeImageAt(idx),
                                          child: const CircleAvatar(
                                            backgroundColor: Colors.red,
                                            child: Icon(Icons.close, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : GestureDetector(
                                onTap: _isUploadingImage ? null : _pickImages,
                                child: Container(
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
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _pickImages,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Photos'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                          ),
                          if (_isUploadingImage) const Text('Uploading...', style: TextStyle(color: Colors.white)),
                          if (!_isUploadingImage && _uploadedImageUrls.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text('${_uploadedImageUrls.length} uploaded', style: const TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(_nameController, "Item Name", Icons.label),
                const SizedBox(height: 12),
                _buildTextField(_priceController, "Price", Icons.attach_money, inputType: TextInputType.number),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: "Category",
                  icon: Icons.category,
                  value: selectedCategory,
                  items: ['Grocery','Gadgets','Stationery','Books','Electronics','Clothing'],
                  onChanged: (v) => setState(() { selectedCategory = v!; _selectedExpiryDate = null; }),
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
                    Expanded(child: _buildTextField(_quantityController, "Quantity", Icons.numbers)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(_unitController, "Unit (kg, pcs...)", Icons.scale)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(_locationController, "Location (optional)", Icons.location_on_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use current location'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickLocationOnMap,
                        icon: const Icon(Icons.map),
                        label: const Text('Pick on map'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(_notesController, "Notes (optional)", Icons.notes, maxLines: 2),

                // Grocery expiry date
                if (selectedCategory == 'Grocery')
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _pickExpiryDate,
                      icon: const Icon(Icons.date_range),
                      label: Text(_selectedExpiryDate == null
                          ? 'Select Expiry Date'
                          : 'Expiry: ${_selectedExpiryDate!.toLocal().toString().split(' ')[0]}'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                    ),
                  ),

                // Rent-specific fields
                if (selectedPurpose == 'Rent') ...[
                  const SizedBox(height: 12),
                  _buildTextField(_rentalPriceController, "Rental Price", Icons.attach_money, inputType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildTextField(_depositController, "Deposit / Security Fee (Optional)", Icons.money_off, inputType: TextInputType.number),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_minDurationController, "Min Duration", Icons.timelapse, inputType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(_maxDurationController, "Max Duration", Icons.timelapse_outlined, inputType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: "Duration Unit",
                    icon: Icons.access_time,
                    value: selectedDurationUnit,
                    items: ['Days', 'Weeks', 'Months'],
                    onChanged: (v) => setState(() => selectedDurationUnit = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickRentalStartDate,
                          icon: const Icon(Icons.date_range),
                          label: Text(_rentalStartDate == null
                              ? 'Rental Start Date'
                              : '${_rentalStartDate!.toLocal().toString().split(' ')[0]}'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickRentalEndDate,
                          icon: const Icon(Icons.date_range),
                          label: Text(_rentalEndDate == null
                              ? 'Rental End Date'
                              : '${_rentalEndDate!.toLocal().toString().split(' ')[0]}'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final specs = await Navigator.pushNamed(
                            context,
                            '/specs',
                            arguments: {'category': selectedCategory, 'condition': selectedCondition},
                          );
                          if (specs != null && specs is Map<String, dynamic>) setState(() => _specs = specs);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: Text(_specs == null ? 'Add Specifications' : 'Edit Specifications'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isLoading
                          ? CircularProgressIndicator(color: AppTheme.terracotta)
                          : ElevatedButton(
                              onPressed: _saveItem,
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta, padding: const EdgeInsets.symmetric(vertical: 14)),
                              child: const Text("Save Item", style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
  }) {
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
          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.black87))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _pickedLocation = LatLng(pos.latitude, pos.longitude);
        _locationController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      });
    } catch (_) {}
  }

  Future<void> _pickLocationOnMap() async {
    final picked = await Navigator.push<LatLng?>(context, MaterialPageRoute(builder: (_) => const MapPickerScreen()));
    if (picked != null) {
      setState(() {
        _pickedLocation = picked;
        _locationController.text = '${picked.latitude.toStringAsFixed(6)}, ${picked.longitude.toStringAsFixed(6)}';
      });
    }
  }
}

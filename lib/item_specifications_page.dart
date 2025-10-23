import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class ItemSpecificationsPage extends StatefulWidget {
  final String category;
  final String condition;

  const ItemSpecificationsPage({
    super.key,
    required this.category,
    this.condition = 'New',
  });

  @override
  State<ItemSpecificationsPage> createState() => _ItemSpecificationsPageState();
}

class _ItemSpecificationsPageState extends State<ItemSpecificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  DateTime? _expiryDate;
  DateTime? _purchaseDate;

  @override
  void initState() {
    super.initState();
    for (final k in _fieldsForCategory(widget.category)) {
      _controllers[k] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  List<String> _fieldsForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'clothing':
        return ['Brand', 'Size', 'Color', 'Material', 'Gender', 'Fit Type'];
      case 'gadgets':
        return ['Brand', 'Model', 'Processor', 'RAM', 'Storage', 'Warranty'];
      case 'books':
        return ['Author', 'Publisher', 'Edition', 'Language'];
      case 'grocery':
        return ['Brand', 'Weight', 'Storage Type'];
      case 'electronics':
        return ['Brand', 'Model', 'Warranty', 'Battery Backup'];
      case 'stationery':
        return ['Brand', 'Material', 'Pack Size', 'Type'];
      default:
        return ['Brand', 'Details'];
    }
  }

  Widget _buildTextField(String label, {String? hint}) {
    final controller = _controllers[label]!;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Enter $label' : null,
    );
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final Map<String, dynamic> specs = {};
    for (final entry in _controllers.entries) {
      final v = entry.value.text.trim();
      if (v.isNotEmpty) specs[entry.key] = v;
    }
    if (_expiryDate != null) specs['expiryDate'] = _expiryDate;
    if (_purchaseDate != null) specs['purchaseDate'] = _purchaseDate;
    Navigator.pop(context, specs);
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsForCategory(widget.category);
    final needsPurchaseDate = widget.condition.toLowerCase() != 'new';
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} Specifications'),
  backgroundColor: AppTheme.terracotta,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fields.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTextField(f),
                    ),
                  ),
                  if (widget.category.toLowerCase() == 'grocery')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: _pickExpiryDate,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _expiryDate == null
                              ? 'Pick Expiry Date'
                              : 'Expiry: ${_expiryDate!.toLocal().toString().split(' ')[0]}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                        ),
                      ),
                    ),
                  if (needsPurchaseDate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: _pickPurchaseDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          _purchaseDate == null
                              ? 'Select Date of Purchase'
                              : 'Purchased: ${_purchaseDate!.toLocal().toString().split(' ')[0]}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.terracotta,
                          ),
                          child: const Text('Save Specifications'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

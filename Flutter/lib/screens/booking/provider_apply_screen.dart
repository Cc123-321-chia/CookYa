// screens/booking/provider_apply_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';

class ProviderApplyScreen extends StatefulWidget {
  final InstructorProfile? existingProfile;

  const ProviderApplyScreen({super.key, this.existingProfile});

  bool get isEditing => existingProfile != null;

  @override
  State<ProviderApplyScreen> createState() => _ProviderApplyScreenState();
}

class _ProviderApplyScreenState extends State<ProviderApplyScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Class info
  final TextEditingController _classTitleController = TextEditingController();
  final TextEditingController _classDescriptionController =
      TextEditingController();
  final TextEditingController _priceNumberController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController();

  String _selectedCurrency = 'RM';

  // Tags
  final List<String> _availableTags = [
    'In-Person',
    'Home Visit',
    'Certificate',
  ];
  List<String> _selectedTags = [];
  final TextEditingController _customTagController = TextEditingController();
  bool _isAddingCustomTag = false;

  // Dishes
  List<String> _dishes = [];
  final TextEditingController _dishController = TextEditingController();

  // Certificates
  List<String> _certificates = [];
  final TextEditingController _certificateController = TextEditingController();

  // Currencies
  final List<String> _currencies = [
    'RM', '฿', '¥', '€', '₫', 'HK\$', '₩', 'S\$', '₹', '₱', '₴', '₦',
    'R\$', '£', 'CHF', 'kr', 'zł', 'Kč', 'Ft', 'lei', '₺', '₪', '﷼', 'Rs',
  ];

  File? _shopAvatar;
  List<File> _shopPhotos = [];
  File? _businessLicense;
  File? _foodLicense;
  File? _healthCertificate;
  File? _chefCertification;
  File? _insurance;
  File? _foodSafetyCertificate;

  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final p = widget.existingProfile!;
      _shopNameController.text = p.shopName;
      _descriptionController.text = p.description;
      _addressController.text = p.address;
      _phoneController.text = p.phone;
      _emailController.text = p.email;

      _classTitleController.text = p.classTitle;
      _classDescriptionController.text = p.classDescription;
      _scheduleController.text = p.schedule;
      _selectedTags = List.from(p.tags);
      _dishes = List.from(p.dishes);
      _certificates = List.from(p.certificates);

      // Split "RM 180" → currency "RM", number "180"
      if (p.price.isNotEmpty) {
        final parts = p.price.split(' ');
        if (parts.length >= 2) {
          _selectedCurrency = parts.first;
          _priceNumberController.text = parts.sublist(1).join(' ');
        } else {
          _priceNumberController.text = p.price;
        }
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _classTitleController.dispose();
    _classDescriptionController.dispose();
    _priceNumberController.dispose();
    _scheduleController.dispose();
    _customTagController.dispose();
    _dishController.dispose();
    _certificateController.dispose();
    super.dispose();
  }

  // ============ Image pickers ============

  Future<void> _pickImage(File? current, Function(File) onPicked) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) onPicked(File(image.path));
  }

  Future<void> _pickMultiImages() async {
    final List<XFile>? images = await _picker.pickMultiImage(imageQuality: 80);
    if (images != null) {
      setState(() {
        for (XFile image in images) {
          if (_shopPhotos.length < 9) _shopPhotos.add(File(image.path));
        }
      });
    }
  }

  // ============ Submit ============

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!widget.isEditing) {
      if (_shopAvatar == null) {
        _showSnackBar('Please upload a shop avatar');
        return;
      }
      if (_businessLicense == null) {
        _showSnackBar('Please upload your business license');
        return;
      }
      if (_foodLicense == null) {
        _showSnackBar('Please upload your food license');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    String price = '';
    if (_priceNumberController.text.trim().isNotEmpty) {
      price = '$_selectedCurrency ${_priceNumberController.text.trim()}';
    }

    Map<String, dynamic> result;

    if (widget.isEditing) {
      // Edit mode → save instantly, no admin review
      result = await ApiService.editInstructorProfile(
        shopName: _shopNameController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        classTitle: _classTitleController.text,
        classDescription: _classDescriptionController.text,
        price: price,
        schedule: _scheduleController.text,
        tags: _selectedTags,
        dishes: _dishes,
        certificates: _certificates,
        avatar: _shopAvatar,
        businessLicense: _businessLicense,
        foodLicense: _foodLicense,
        healthCertificate: _healthCertificate,
        chefCertification: _chefCertification,
        insurance: _insurance,
        foodSafetyCertificate: _foodSafetyCertificate,
        shopPhotos: _shopPhotos,
      );
    } else {
      result = await ApiService.applyInstructor(
        shopName: _shopNameController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        classTitle: _classTitleController.text,
        classDescription: _classDescriptionController.text,
        price: price,
        schedule: _scheduleController.text,
        tags: _selectedTags,
        dishes: _dishes,
        certificates: _certificates,
        avatar: _shopAvatar,
        businessLicense: _businessLicense,
        foodLicense: _foodLicense,
        healthCertificate: _healthCertificate,
        chefCertification: _chefCertification,
        insurance: _insurance,
        foodSafetyCertificate: _foodSafetyCertificate,
        shopPhotos: _shopPhotos,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      _showSnackBar(result['error'] ?? 'Failed');
    }
  }

  void _showSuccessDialog() {
    final isEditing = widget.isEditing;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: (isEditing ? const Color(0xFF4CAF50) : const Color(0xFFFFB347))
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEditing ? Icons.check_circle : Icons.hourglass_top,
                color: isEditing
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFFB347),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isEditing ? 'Changes Saved!' : 'Application Submitted!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ],
        ),
        content: Text(
          isEditing
              ? 'Your changes have been saved.'
              : 'Your application is being reviewed by admin.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF6B4C2A).withValues(alpha: 0.7),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(
              'Got it!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFFB347),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit' : 'Apply as Provider',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          color: const Color(0xFF6B4C2A),
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ============ SHOP INFO ============
                    _buildSectionTitle('Basic Information', Icons.store),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _shopNameController,
                      label: 'Shop Name',
                      hint: 'e.g., Bangkok Kitchen Studio',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Shop Description',
                      hint: 'Describe your shop...',
                      maxLines: 3,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      hint: 'Full address',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneController,
                            label: 'Phone',
                            hint: 'Contact number',
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),

                    // ============ CLASS INFO ============
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                        'Class Information', Icons.restaurant_menu),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _classTitleController,
                      label: 'Class Title',
                      hint: 'e.g., Authentic Thai Cooking Class',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _classDescriptionController,
                      label: 'Class Description',
                      hint: 'Describe your class...',
                      maxLines: 3,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Price
                    Text(
                      'Price',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              items: _currencies.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedCurrency = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _priceNumberController,
                            label: '',
                            hint: 'e.g., 180',
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _scheduleController,
                      label: 'Schedule',
                      hint: 'e.g., Mon - Fri, 9:00 AM - 12:00 PM',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),

                    // ============ TAGS ============
                    const SizedBox(height: 24),
                    _buildSectionTitle('Tags', Icons.local_offer),
                    const SizedBox(height: 12),
                    _buildTagsSection(),

                    // ============ DISHES ============
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                        'What You\'ll Learn (Dishes)', Icons.restaurant),
                    const SizedBox(height: 12),
                    _buildListSection(
                      items: _dishes,
                      controller: _dishController,
                      hint: 'e.g., Pad Thai',
                      addLabel: 'Add Dish',
                      onAdd: (v) => setState(() => _dishes.add(v)),
                      onRemove: (i) => setState(() => _dishes.removeAt(i)),
                    ),

                    // ============ CERTIFICATES ============
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                        'What You\'ll Get (Certificates)', Icons.emoji_events),
                    const SizedBox(height: 12),
                    _buildListSection(
                      items: _certificates,
                      controller: _certificateController,
                      hint: 'e.g., Certificate of Completion',
                      addLabel: 'Add Certificate',
                      onAdd: (v) => setState(() => _certificates.add(v)),
                      onRemove: (i) => setState(() => _certificates.removeAt(i)),
                    ),

                    // ============ LEGAL DOCS ============
                    const SizedBox(height: 24),
                    _buildSectionTitle('Legal Documents', Icons.verified),
                    const SizedBox(height: 12),
                    _buildImageUploadTile(
                      label: 'Business License *',
                      subtitle: 'Official business registration',
                      file: _businessLicense,
                      onTap: () => _pickImage(_businessLicense, (f) {
                        setState(() => _businessLicense = f);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildImageUploadTile(
                      label: 'Food License *',
                      subtitle: 'Food establishment license',
                      file: _foodLicense,
                      onTap: () => _pickImage(_foodLicense, (f) {
                        setState(() => _foodLicense = f);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildImageUploadTile(
                      label: 'Health Certificate',
                      subtitle: 'Optional',
                      file: _healthCertificate,
                      onTap: () => _pickImage(_healthCertificate, (f) {
                        setState(() => _healthCertificate = f);
                      }),
                    ),

                    // ============ CERTIFICATIONS ============
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                        'Certifications (Optional)', Icons.emoji_events),
                    const SizedBox(height: 12),
                    _buildImageUploadTile(
                      label: 'Chef Certification',
                      subtitle: 'Professional chef certification',
                      file: _chefCertification,
                      onTap: () => _pickImage(_chefCertification, (f) {
                        setState(() => _chefCertification = f);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildImageUploadTile(
                      label: 'Insurance Certificate',
                      subtitle: 'Liability insurance',
                      file: _insurance,
                      onTap: () => _pickImage(_insurance, (f) {
                        setState(() => _insurance = f);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildImageUploadTile(
                      label: 'Food Safety Certificate',
                      subtitle: 'Food handling training',
                      file: _foodSafetyCertificate,
                      onTap: () => _pickImage(_foodSafetyCertificate, (f) {
                        setState(() => _foodSafetyCertificate = f);
                      }),
                    ),

                    // ============ SHOP MEDIA ============
                    const SizedBox(height: 24),
                    _buildSectionTitle('Shop Media', Icons.photo_library),
                    const SizedBox(height: 12),
                    _buildImageUploadTile(
                      label: 'Shop Avatar *',
                      subtitle: 'Your shop logo',
                      file: _shopAvatar,
                      onTap: () => _pickImage(_shopAvatar, (f) {
                        setState(() => _shopAvatar = f);
                      }),
                      showRemove: true,
                      onRemove: () => setState(() => _shopAvatar = null),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Shop Photos (up to 9)',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _shopPhotos.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == _shopPhotos.length) {
                            return GestureDetector(
                              onTap: _pickMultiImages,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFD966),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 40,
                                  color: Color(0xFFFFB347),
                                ),
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(_shopPhotos[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _shopPhotos.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD966),
                          foregroundColor: const Color(0xFF6B4C2A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          widget.isEditing ? 'Save' : 'Submit Application',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ============ Helpers ============

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._availableTags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFD966) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFD966)
                          : const Color(0xFFFFB347),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check,
                            size: 14, color: Color(0xFF6B4C2A)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tag,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6B4C2A),
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!_isAddingCustomTag)
              GestureDetector(
                onTap: () => setState(() => _isAddingCustomTag = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFB347), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add,
                          size: 16, color: Color(0xFFFFB347)),
                      const SizedBox(width: 4),
                      Text(
                        'Other',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFFFB347), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_isAddingCustomTag)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTagController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter custom tag...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final v = _customTagController.text.trim();
                    if (v.isNotEmpty) {
                      setState(() {
                        _selectedTags.add(v);
                        _customTagController.clear();
                        _isAddingCustomTag = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.check_circle,
                      color: Color(0xFFFFB347)),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isAddingCustomTag = false;
                      _customTagController.clear();
                    });
                  },
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                ),
              ],
            ),
          ),
        if (_selectedTags.where((t) => !_availableTags.contains(t)).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTags
                  .where((t) => !_availableTags.contains(t))
                  .map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD966),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFFFB347), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF6B4C2A), fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedTags.remove(tag)),
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFFFB347)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildListSection({
    required List<String> items,
    required TextEditingController controller,
    required String hint,
    required String addLabel,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.asMap().entries.map((entry) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD966),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFFFFB347), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value,
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF6B4C2A), fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFFFFB347)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        if (items.isNotEmpty) const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.isNotEmpty) {
                  onAdd(v);
                  controller.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD966),
                foregroundColor: const Color(0xFF6B4C2A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                addLabel,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFFB347)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadTile({
    required String label,
    required String subtitle,
    required File? file,
    required VoidCallback onTap,
    bool showRemove = false,
    VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                file != null ? const Color(0xFFFFD966) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : const Icon(
                      Icons.cloud_upload,
                      size: 30,
                      color: Color(0xFFFFB347),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  Text(
                    file != null ? 'File uploaded' : subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: file != null
                          ? Colors.green
                          : const Color(0xFFC9A96E),
                    ),
                  ),
                ],
              ),
            ),
            if (showRemove && file != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
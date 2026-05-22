import 'dart:io';
import 'package:flutter/material.dart';
import '../services/bg_remover.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/local_db.dart';
import 'home_page.dart';
import 'manual_bg_remover_page.dart';

class AddItemPage extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final bool isWeb;
  final Map<String, dynamic>? existingItem;

  const AddItemPage({
    super.key,
    this.imageFile,
    this.imageBytes,
    required this.isWeb,
    this.existingItem,
  });

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  // Renamed from _brandController — now represents "Name"
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  final Map<String, List<String>> _categoryMap = {
    'Tops': ['T-shirt', 'Hoodie', 'Activewear', 'Other'],
    'Bottoms': ['Skirts', 'Trouser', 'Shorts', 'Jeans', 'Activewear', 'Other'],
    'Outerwear': ['Coats', 'Jackets', 'Capes', 'Other'],
    'Underwear & Nightwear': ['Underwear', 'Nightwear'],
    'Accessories': ['Ties', 'Scarves', 'Gloves', 'Socks', 'Other'],
    'Footwear': ['Flats', 'Sandals', 'Boots', 'Sport Shoes', 'Other'],
    'Bag': ['Handbag', 'Backpack', 'Shoulder Bag', 'Crossbody', 'Clutch', 'Tote', 'Other'],
  };

  String? _selectedMainCategory;
  String? _selectedSubCategory;
  final List<String> _colors = [];

  // Image related variables
  File? _currentImageFile;
  Uint8List? _currentImageBytes;
  String? _existingImagePath;
  bool _imageChanged = false;
  bool _isProcessingBg = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeImage();
    if (widget.existingItem != null) {
      _initializeExistingItem();
    }
  }

  void _initializeImage() {
    if (widget.existingItem != null &&
        widget.existingItem!['imagePath'] != null) {
      _existingImagePath = widget.existingItem!['imagePath'];
    }

    if (widget.imageFile != null || widget.imageBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processInitialImage();
      });
    }
  }

  Future<void> _processInitialImage() async {
    setState(() => _isProcessingBg = true);
    try {
      if (widget.isWeb && widget.imageBytes != null) {
        final processed = await BgRemover.processBytes(widget.imageBytes!);
        if (!mounted) return;
        setState(() {
          _currentImageBytes = processed ?? widget.imageBytes;
          _currentImageFile = null;
          _isProcessingBg = false;
        });
      } else if (widget.imageFile != null) {
        final processedPath = await BgRemover.process(widget.imageFile!.path);
        if (!mounted) return;
        setState(() {
          _currentImageFile = File(processedPath ?? widget.imageFile!.path);
          _currentImageBytes = null;
          _isProcessingBg = false;
        });
      } else {
        setState(() => _isProcessingBg = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingBg = false);
    }
  }

  void _initializeExistingItem() {
    final item = widget.existingItem!;
    // 'brand' column in DB is reused for Name
    _nameController.text = item['brand'] ?? '';
    _colors.addAll(
      (item['colors'] ?? '').toString().split(',').where((c) => c.isNotEmpty),
    );
    _selectedMainCategory = item['mainCategory'];
    _selectedSubCategory = item['category'];
  }

  // ── Returns the image file that is currently displayed in the preview ──────
  // This is what gets passed to the manual bg remover instead of picking a new one.
  File? _getCurrentDisplayFile() {
    if (_currentImageFile != null) return _currentImageFile;
    if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      return File(_existingImagePath!);
    }
    return null;
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Image Source',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepOrange),
                title: const Text('Camera'),
                subtitle: const Text('Auto background removal'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepOrange),
                title: const Text('Gallery'),
                subtitle: const Text('Auto background removal'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              // ── Manual background remover ─────────────────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.colorize, color: Colors.deepOrange),
                ),
                title: const Text(
                  'Manual Background Remover',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _hasCurrentImage()
                      ? 'Edit the current image manually'
                      : 'Pick an image first, then edit manually',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openManualBgRemover();
                },
              ),
              if (_hasCurrentImage()) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Image'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage();
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Opens the manual remover using whatever image is currently displayed.
  /// If no image exists yet, prompts the user to pick one from gallery first.
  Future<void> _openManualBgRemover() async {
    File? fileToEdit = _getCurrentDisplayFile();

    // No image yet — if we have bytes (web), save to a temp file first
    if (fileToEdit == null && _currentImageBytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final tmpPath = '${dir.path}/tmp_manual_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tmpPath).writeAsBytes(_currentImageBytes!);
      fileToEdit = File(tmpPath);
    }

    // Still no image — ask user to pick one from gallery first
    if (fileToEdit == null) {
      _showErrorSnackbar('Please add an image first before using the manual remover.');
      return;
    }

    if (!mounted) return;

    final result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualBgRemoverPage(imageFile: fileToEdit!),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentImageFile = result;
        _currentImageBytes = null;
        _existingImagePath = null;
        _imageChanged = true;
      });
      _showSuccessSnackbar('Manual background removed successfully!');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() {
        _imageChanged = true;
        _isProcessingBg = true;
      });

      if (widget.isWeb) {
        final bytes = await image.readAsBytes();
        final processed = await BgRemover.processBytes(bytes);
        if (!mounted) return;
        setState(() {
          _currentImageBytes = processed ?? bytes;
          _currentImageFile = null;
          _isProcessingBg = false;
        });
      } else {
        final processedPath = await BgRemover.process(image.path);
        if (!mounted) return;
        setState(() {
          _currentImageFile = File(processedPath ?? image.path);
          _currentImageBytes = null;
          _isProcessingBg = false;
        });
      }

      _showSuccessSnackbar('Background removed successfully!');
    } catch (e) {
      if (mounted) setState(() => _isProcessingBg = false);
      _showErrorSnackbar('Failed to process image: ${e.toString()}');
    }
  }

  void _removeImage() {
    setState(() {
      _currentImageFile = null;
      _currentImageBytes = null;
      _existingImagePath = null;
      _imageChanged = true;
    });
    _showSuccessSnackbar('Image removed successfully!');
  }

  bool _hasCurrentImage() {
    return _currentImageFile != null ||
        _currentImageBytes != null ||
        (_existingImagePath != null && _existingImagePath!.isNotEmpty);
  }

  void _addColor(String color) {
    if (color.trim().isNotEmpty && !_colors.contains(color.trim())) {
      setState(() => _colors.add(color.trim()));
      _colorController.clear();
    }
  }

  Future<void> _saveItem() async {
    if (_colorController.text.trim().isNotEmpty) {
      _addColor(_colorController.text);
    }

    if (!_hasCurrentImage() && widget.existingItem == null) {
      _showErrorSnackbar('Please select an image first');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackbar('Name is required');
      return;
    }

    if (_selectedMainCategory == null) {
      _showErrorSnackbar('Please select a main category');
      return;
    }

    final itemData = <String, dynamic>{
      'mainCategory': _selectedMainCategory ?? '',
      'category': _selectedSubCategory ?? '',
      'brand': _nameController.text.trim(), // stored in 'brand' column
      'size': '',
      'price': '',
      'tags': '',
      'colors': _colors.join(','),
      'datePurchased': '',
    };

    // Handle image path
    if (_imageChanged) {
      if (_currentImageFile != null) {
        itemData['imagePath'] = _currentImageFile!.path;
      } else if (_currentImageBytes != null) {
        itemData['imagePath'] = '';
      } else {
        itemData['imagePath'] = '';
      }
    } else if (widget.existingItem != null &&
        widget.existingItem!['imagePath'] != null) {
      itemData['imagePath'] = widget.existingItem!['imagePath'];
    } else if (_currentImageFile != null) {
      itemData['imagePath'] = _currentImageFile!.path;
    } else {
      itemData['imagePath'] = '';
    }

    try {
      final db = DBHelper.instance;

      if (widget.existingItem != null && widget.existingItem!['id'] != null) {
        itemData['id'] = widget.existingItem!['id'];
        await db.updateItem(itemData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final newId = await db.addItem(itemData);

        if (newId == -1) {
          _showErrorSnackbar('Failed to save item. Please try again.');
          return;
        }

        _showSuccessSnackbar('Item saved successfully!');
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      debugPrint('Error saving item: $e');
      _showErrorSnackbar('Error saving item: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.existingItem != null ? 'Edit Item' : 'Add New Item',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Image Section ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: const Size(200, 200),
                              painter: _CheckerboardPainter(),
                            ),
                            _buildImagePreview(),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to change photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Form Section ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Field (was Brand)
                  _buildSectionTitle('Item Information', Icons.label_outline),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter item name',
                    icon: Icons.local_offer,
                    required: true,
                  ),

                  const SizedBox(height: 32),

                  // Category Section
                  _buildSectionTitle('Category', Icons.category),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: _selectedMainCategory,
                    label: 'Main Category',
                    hint: 'Select main category',
                    icon: Icons.folder,
                    items: _categoryMap.keys.map((mainCat) {
                      return DropdownMenuItem(
                        value: mainCat,
                        child: Text(mainCat),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMainCategory = value;
                        _selectedSubCategory = null;
                      });
                    },
                    required: true,
                  ),

                  if (_selectedMainCategory != null) ...[
                    const SizedBox(height: 16),
                    _buildDropdown(
                      value: _selectedSubCategory,
                      label: 'Sub Category',
                      hint: 'Select sub category',
                      icon: Icons.folder_open,
                      items: _categoryMap[_selectedMainCategory]!.map((sub) {
                        return DropdownMenuItem(
                          value: sub,
                          child: Text(sub),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedSubCategory = value),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Colors Section
                  _buildSectionTitle('Colors', Icons.palette),
                  const SizedBox(height: 16),
                  if (_colors.isNotEmpty)
                    _buildChipDisplay('Colors', _colors, _colors.remove),
                  _buildAddField(
                    controller: _colorController,
                    label: 'Add Color',
                    hint: 'Enter color name',
                    icon: Icons.colorize,
                    onSubmitted: _addColor,
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_isProcessingBg) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepOrange),
            SizedBox(height: 10),
            Text(
              'Removing background…',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_currentImageFile != null) {
      return SizedBox.expand(
        child: Image.file(_currentImageFile!, fit: BoxFit.contain),
      );
    } else if (_currentImageBytes != null) {
      return SizedBox.expand(
        child: Image.memory(_currentImageBytes!, fit: BoxFit.contain),
      );
    } else if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      return SizedBox.expand(
        child: Image.file(File(_existingImagePath!), fit: BoxFit.contain),
      );
    } else {
      return const Center(
        child: Icon(Icons.add_a_photo, size: 64, color: Colors.grey),
      );
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepOrange, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
    TextInputType? keyboardType,
    String? prefix,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, required: required),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.deepOrange),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
            prefixText: prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, required: required),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.deepOrange),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(16),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildAddField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.deepOrange),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add, color: Colors.deepOrange),
              onPressed: () => onSubmitted(controller.text),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(16),
          ),
          onFieldSubmitted: onSubmitted,
        ),
      ],
    );
  }

  Widget _buildChipDisplay(
    String title,
    List<String> items,
    Function(String) onRemove,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.deepOrange[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item,
                        style: TextStyle(
                          color: Colors.deepOrange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => onRemove(item)),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.deepOrange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.black87,
        ),
        children: required
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepOrange, Colors.orange],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessingBg ? null : _saveItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingItem != null ? 'Update Item' : 'Save Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a grey/white checkerboard pattern to indicate image transparency.
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 10.0;
    final paintLight = Paint()..color = const Color(0xFFE0E0E0);
    final paintDark = Paint()..color = const Color(0xFFBDBDBD);

    for (double y = 0; y < size.height; y += tileSize) {
      for (double x = 0; x < size.width; x += tileSize) {
        final isEven =
            ((x / tileSize).floor() + (y / tileSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isEven ? paintLight : paintDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
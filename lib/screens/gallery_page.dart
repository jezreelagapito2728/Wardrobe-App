import '../../utils/constants.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';





class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> with SingleTickerProviderStateMixin {
  List<XFile> _allImages = [];
  List<String> _folders = ['All Photos'];
  String _selectedFolder = 'All Photos';
  bool _isLoading = false;
  bool _permissionDenied = false;
  final ImagePicker _picker = ImagePicker();
  int? _selectedImageIndex;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
    _checkAndRequestPermissions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    PermissionStatus status = await Permission.photos.status;

    if (status.isDenied) {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      await _loadGalleryImages();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _permissionDenied = true;
      });
      _showPermissionDeniedDialog();
    } else {
      setState(() {
        _permissionDenied = true;
      });
    }
  }

  Future<void> _loadGalleryImages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (mounted) {
        setState(() {
          _allImages = images;
          _isLoading = false;
          _extractFoldersFromImages(images);

          String defaultFolder = 'All Photos';
          if (_folders.contains('Camera')) {
            defaultFolder = 'Camera';
          } else if (_folders.contains('Screenshots')) {
            defaultFolder = 'Screenshots';
          }
          if (_selectedFolder == 'All Photos') {
            _selectedFolder = defaultFolder;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Failed to load gallery images: $e');
      }
    }
  }

  void _extractFoldersFromImages(List<XFile> images) {
    Set<String> folderSet = {'All Photos'};

    for (var image in images) {
      try {
        final File file = File(image.path);
        final String parentPath = file.parent.path;
        final List<String> pathParts = parentPath.split(Platform.pathSeparator);
        if (pathParts.isNotEmpty) {
          folderSet.add(pathParts.last);
        }
      } catch (e) {
        continue;
      }
    }

    setState(() {
      _folders = folderSet.toList()..sort();
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: linen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Permission Required', style: TextStyle(color: forestInk, fontWeight: FontWeight.w700)),
        content: Text(
          'Gallery access is required to view your photos. '
          'Please grant permission in Settings to continue.',
          style: TextStyle(color: forestInk.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: forestInk.withValues(alpha: 0.7))),
          ),
          _ModernButton(
            text: 'Open Settings',
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            height: 44,
          ),
        ],
      ),
    );
  }

  Future<void> _addPhotoFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _allImages.insert(0, image);
          _extractFoldersFromImages(_allImages);
          _selectedFolder = 'All Photos';
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to add photo: $e');
      }
    }
  }

  Future<void> _deletePhoto(XFile image) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: linen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Photo', style: TextStyle(color: forestInk, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this photo?', style: TextStyle(color: forestInk.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: forestInk.withValues(alpha: 0.7))),
          ),
          _ModernButton(
            text: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
            backgroundColor: Colors.red.shade600,
            height: 44,
          ),
        ],
      ),
    );

    if (confirmDelete == true && mounted) {
      setState(() {
        _allImages.remove(image);

        if (_allImages.isNotEmpty) {
          _extractFoldersFromImages(_allImages);
        } else {
          _folders = ['All Photos'];
          _selectedFolder = 'All Photos';
        }

        if (_selectedImageIndex != null &&
            _allImages.length <= _selectedImageIndex!) {
          _selectedImageIndex = null;
        }
      });

      _showSuccessSnackbar('Photo deleted successfully');
    }
  }

  void _onFolderSelected(String folder) {
    setState(() {
      _selectedFolder = folder;
      _selectedImageIndex = null;
    });
  }

  List<XFile> _getFilteredImages() {
    if (_selectedFolder == 'All Photos') {
      return _allImages;
    }

    return _allImages.where((image) {
      try {
        final File file = File(image.path);
        final String parentPath = file.parent.path;
        final List<String> pathParts = parentPath.split(Platform.pathSeparator);
        return pathParts.last == _selectedFolder;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: Colors.red.shade600,
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
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: const Color(0xFF2D6A4F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  floating: true,
                  snap: true,
                  elevation: 0,
                  backgroundColor: linen,
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    'Gallery',
                    style: TextStyle(
                      color: forestInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      letterSpacing: -0.5,
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    _AnimatedActionButton(
                      icon: Icons.add_photo_alternate_rounded,
                      onPressed: _addPhotoFromGallery,
                      tooltip: 'Add Photo',
                    ),
                    _AnimatedActionButton(
                      icon: Icons.refresh_rounded,
                      onPressed: _loadGalleryImages,
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Folder Selector
                      _buildFolderSelector(),

                      // Gallery Grid
                      _permissionDenied
                          ? _buildPermissionDeniedView()
                          : _isLoading
                              ? _buildLoadingView()
                              : _buildGalleryGrid(),
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

  Widget _buildFolderSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: softSage.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFolder,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: softSage, size: 24),
          elevation: 16,
          style: TextStyle(
            color: forestInk,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: linen,
          borderRadius: BorderRadius.circular(16),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _onFolderSelected(newValue);
            }
          },
          items: _folders.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: forestInk.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: forestInk.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gallery Permission Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: forestInk,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please grant gallery access to view your photos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: forestInk.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            _ModernButton(
              text: 'Grant Permission',
              onPressed: _checkAndRequestPermissions,
              icon: Icon(Icons.lock_open_rounded, size: 20),
              height: 56,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: forestInk),
          const SizedBox(height: 16),
          Text(
            'Loading gallery...',
            style: TextStyle(
              fontSize: 16,
              color: forestInk.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: forestInk.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_not_supported_rounded,
                size: 48,
                color: forestInk.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No images found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: forestInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add photos from your gallery to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: forestInk.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 28),
            _ModernButton(
              text: 'Add Photos',
              onPressed: _addPhotoFromGallery,
              icon: Icon(Icons.add_photo_alternate_rounded, size: 20),
              height: 56,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final List<XFile> imagesToShow = _getFilteredImages();

    if (imagesToShow.isEmpty) {
      return _buildEmptyView();
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final image = imagesToShow[index];
            final bool isSelected = _selectedImageIndex == index;

            return _GalleryGridItem(
              image: image,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedImageIndex = index;
                });
              },
              onLongPress: () => _deletePhoto(image),
            );
          },
          childCount: imagesToShow.length,
        ),
      ),
    );
  }
}

// ============ Gallery Grid Item ============

class _GalleryGridItem extends StatelessWidget {
  final XFile image;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GalleryGridItem({
    required this.image,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: forestInk, width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? forestInk.withValues(alpha: 0.2)
                  : forestInk.withValues(alpha: 0.06),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(image.path),
              fit: BoxFit.cover,
            ),
            // Overlay for selected state
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            // Selected indicator
            if (isSelected)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============ Animated Action Button ============

class _AnimatedActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _AnimatedActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: forestInk.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: forestInk, size: 22),
        ),
      ),
    );
  }
}

// ============ Modern Button ============

class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final double height;
  final Color? backgroundColor;

  const _ModernButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.height = 52,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ?? forestInk;
    final effectiveForeground = isOutlined ? effectiveBackground : linen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: isOutlined
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: onPressed != null
                  ? [
                      BoxShadow(
                        color: effectiveBackground.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : effectiveBackground,
          foregroundColor: effectiveForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isOutlined
              ? BorderSide(color: effectiveBackground.withValues(alpha: 0.5), width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: _buildLabel(),
      ),
    );
  }

  Widget _buildLabel() {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: isOutlined ? forestInk : linen,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: isOutlined ? forestInk : linen,
          ),
        ),
      ],
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<XFile> _allImages = [];
  List<String> _folders = ['All Photos'];
  String _selectedFolder = 'All Photos';
  bool _isLoading = false;
  bool _permissionDenied = false;
  final ImagePicker _picker = ImagePicker();
  int? _selectedImageIndex;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // Check photo library permission
    PermissionStatus status = await Permission.photos.status;

    if (status.isDenied) {
      // We didn't ask for permission yet or the user denied it
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      // Either permission was already granted or just granted
      await _loadGalleryImages();
    } else if (status.isPermanentlyDenied) {
      // The user denied permission and checked "Don't ask again"
      setState(() {
        _permissionDenied = true;
      });
      _showPermissionDeniedDialog();
    } else {
      // Permission denied but can ask again
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
      // Pick multiple images from gallery
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (mounted) {
        setState(() {
          _allImages = images;
          _isLoading = false;

          // Extract unique folder names from image paths
          _extractFoldersFromImages(images);

          // Set default folder to "Camera" if it exists, otherwise "All Photos"
          if (!_isLoading && mounted) {
            String defaultFolder = 'All Photos';
            if (_folders.contains('Camera')) {
              defaultFolder = 'Camera';
            } else if (_folders.contains('Screenshots')) {
              defaultFolder = 'Screenshots';
            }
            if (_selectedFolder == 'All Photos') {
              _selectedFolder = defaultFolder;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load gallery images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _extractFoldersFromImages(List<XFile> images) {
    Set<String> folderSet = {'All Photos'};

    for (var image in images) {
      try {
        final File file = File(image.path);
        final String parentPath = file.parent.path;
        // Get the last part of the path as folder name
        final List<String> pathParts = parentPath.split(Platform.pathSeparator);
        if (pathParts.isNotEmpty) {
          folderSet.add(pathParts.last);
        }
      } catch (e) {
        // Skip if we can't parse the path
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
        title: const Text('Permission Required'),
        content: const Text(
          'Gallery access is required to view your photos. '
          'Please grant permission in Settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
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
          // Add to beginning of list so it shows first
          _allImages.insert(0, image);

          // Update folders if needed
          _extractFoldersFromImages(_allImages);

          // Reset to All Photos to see the new image
          _selectedFolder = 'All Photos';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePhoto(XFile image) async {
    // Show confirmation dialog
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true && mounted) {
      setState(() {
        _allImages.remove(image);

        // Update folders after deletion
        if (_allImages.isNotEmpty) {
          _extractFoldersFromImages(_allImages);
        } else {
          _folders = ['All Photos'];
          _selectedFolder = 'All Photos';
        }

        // Clear selection if deleted image was selected
        if (_selectedImageIndex != null &&
            _allImages.length <= _selectedImageIndex!) {
          _selectedImageIndex = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onFolderSelected(String folder) {
    setState(() {
      _selectedFolder = folder;
      _selectedImageIndex = null; // Clear selection when changing folders
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

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          const Text(
            'Gallery Permission Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Please grant gallery access to view your photos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _checkAndRequestPermissions,
            icon: const Icon(Icons.lock_open),
            label: const Text('Grant Permission'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No images found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addPhotoFromGallery,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Photos'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final List<XFile> imagesToShow = _getFilteredImages();

    if (imagesToShow.isEmpty) {
      return _buildEmptyView();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: imagesToShow.length,
      itemBuilder: (context, index) {
        final image = imagesToShow[index];
        final bool isSelected = _selectedImageIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedImageIndex = index;
            });
          },
          onLongPress: () {
            // Show delete confirmation on long press
            _deletePhoto(image);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
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
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullScreenImage() {
    if (_selectedImageIndex == null) return const SizedBox.shrink();

    final List<XFile> imagesToShow = _getFilteredImages();
    if (_selectedImageIndex! >= imagesToShow.length) {
      _selectedImageIndex = null;
      return const SizedBox.shrink();
    }

    final XFile image = imagesToShow[_selectedImageIndex!];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImageIndex = null;
        });
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Image
            Center(
              child: Hero(
                tag: 'gallery-image-${image.path}',
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // App bar
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedImageIndex = null;
                    });
                  },
                ),
                title: Text(
                  '${_selectedImageIndex! + 1}/${imagesToShow.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () => _deletePhoto(image),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // Show more options menu
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFolder,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6E5A3F)),
          elevation: 16,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _onFolderSelected(newValue);
            }
          },
          items: _folders.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4EAE0),
      appBar: AppBar(
        title: const Text(
          'Gallery',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF4F2D20),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Add photo button
          IconButton(
            icon: const Icon(
              Icons.add_photo_alternate,
              color: Colors.white,
            ),
            tooltip: 'Add Photo',
            onPressed: _addPhotoFromGallery,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadGalleryImages,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFolderSelector(),
        ),
      ),
      body: Stack(
        children: [
          // Main content
          _permissionDenied
              ? _buildPermissionDeniedView()
              : _isLoading
                  ? _buildLoadingView()
                  : _buildGalleryGrid(),

          // Full-screen image view (on top)
          if (_selectedImageIndex != null) _buildFullScreenImage(),
        ],
      ),
      floatingActionButton: !_permissionDenied && !_isLoading
          ? FloatingActionButton(
              backgroundColor: Color(0xFF6E5A3F),
              foregroundColor: Colors.white,
              elevation: 6,
              onPressed: _addPhotoFromGallery,
              tooltip: 'Add Photo',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
// outfit_detail_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'create_outfit_page.dart';
import '../services/local_db.dart';
import 'create_outfit_page.dart';

class OutfitDetailPage extends StatelessWidget {
  final Map<String, dynamic> outfit;
  final bool isWeb;

  const OutfitDetailPage({
    super.key,
    required this.outfit,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4EAE0),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Color(0xFF4F2D20),
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                outfit['name'] ?? 'Outfit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
          ),

          // Content Section
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Outfit Info
                    _buildInfoSection(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !isWeb
          ? FloatingActionButton(
              backgroundColor: Color(0xFF6E5A3F),
              foregroundColor: Colors.white,
              onPressed: () => _navigateToEdit(context),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outfit name already in app bar, but we can show again or show other info
        const SizedBox(height: 16),
        _buildImageRow('Accessories', outfit['accessoriesPath']),
        const SizedBox(height: 16),
        _buildImageRow('Top', outfit['topPath']),
        const SizedBox(height: 16),
        _buildImageRow('Bottom', outfit['bottomPath']),
        const SizedBox(height: 16),
        _buildImageRow('Shoes', outfit['shoesPath']),
        const SizedBox(height: 16),
        _buildImageRow('Bag', outfit['bagPath']),
      ],
    );
  }

  Widget _buildImageRow(String label, String? imagePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        imagePath != null && imagePath.isNotEmpty
            ? SizedBox(
                height: 100,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
      ],
    );
  }

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOutfitPage(
        ),
      ),
    );
    if (result == true) {
      // If outfit was updated, we might want to refresh the detail page.
      // For simplicity, we just pop and let the parent refresh.
      if (context.mounted) {
        Navigator.pop(context, true);
      }
    }
  }
}
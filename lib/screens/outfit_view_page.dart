import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/local_db.dart';

class OutfitViewPage extends StatefulWidget {
  const OutfitViewPage({super.key});

  @override
  State<OutfitViewPage> createState() => _OutfitViewPageState();
}

class _OutfitViewPageState extends State<OutfitViewPage> {
  List<Map<String, dynamic>> _outfits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    final dbHelper = DBHelper.instance;
    final outfits = await dbHelper.getAllOutfits();
    setState(() {
      _outfits = outfits;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Outfits'),
        backgroundColor: const Color(0xff1c1c1c),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _outfits.isEmpty
              ? const Center(
                  child: Text(
                    'No outfits yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _outfits.length,
                  itemBuilder: (context, index) {
                    final outfit = _outfits[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 30,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        outfit['name'] ?? 'Outfit ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${outfit['itemCount'] ?? 0} items',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OutfitDetailPage(
                              outfit: outfit,
                              isWeb: kIsWeb,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

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
      appBar: AppBar(
        title: Text(outfit['name'] ?? 'Outfit'),
        backgroundColor: const Color(0xff1c1c1c),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${outfit['itemCount'] ?? 0} items',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
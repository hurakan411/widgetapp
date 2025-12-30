import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../constants/design.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _partnerIdController = TextEditingController();
  String _myId = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Generate a random ID if not exists (In real app, use Auth ID)
    String? myId = prefs.getString('my_user_id');
    if (myId == null) {
      myId = DateTime.now().millisecondsSinceEpoch.toString(); // Simple dummy ID
      await prefs.setString('my_user_id', myId);
    }

    setState(() {
      _myId = myId!;
      _partnerIdController.text = prefs.getString('partner_user_id') ?? '';
    });
  }

  Future<void> _savePartnerId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('partner_user_id', _partnerIdController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner ID Saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My ID Section
            const Text("My ID", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.neumorphicConcave,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _myId,
                      style: const TextStyle(fontSize: 18, fontFamily: 'Courier', fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.vintageNavy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _myId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // Partner ID Section
            const Text("Partner ID", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: AppStyles.neumorphicConcave,
              child: TextField(
                controller: _partnerIdController,
                style: const TextStyle(fontSize: 18, fontFamily: 'Courier', fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter Partner ID',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.vintageNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _savePartnerId,
                child: const Text("Save Partner ID", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

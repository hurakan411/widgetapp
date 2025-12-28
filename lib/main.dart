import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

// TODO: Replace with your actual Supabase URL and Anon Key
const supabaseUrl = 'https://rqxqhiqnktmeuvfjwwyu.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxeHFoaXFua3RtZXV2Zmp3d3l1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4NjIwNzAsImV4cCI6MjA4MjQzODA3MH0.C4zjXw-yJnpOCIU3MYBQXzYm2hC0SwFjHN-zuc-k8zU';

// App Group ID (Must match the one created in Apple Developer Portal & Xcode)
const appGroupId = 'group.com.shashinoguchi.widgetTask';
const widgetName = 'MessageWidget'; // The name of the widget in Swift

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set App Group ID for HomeWidget
  await HomeWidget.setAppGroupId(appGroupId);

  // Initialize Supabase
  // Note: This will fail if keys are not set. 
  // We wrap in try-catch or just let it fail for the mock if keys are missing.
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed (expected if keys are placeholders): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Widget Message Sync',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _targetUidController = TextEditingController();
  final _messageController = TextEditingController();
  
  String? _myUserId;
  String? _targetUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    
    // 1. Auth (Anonymous)
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        final authResponse = await Supabase.instance.client.auth.signInAnonymously();
        _myUserId = authResponse.user?.id;
      } else {
        _myUserId = session.user.id;
      }
    } catch (e) {
      debugPrint('Auth failed: $e');
      _myUserId = 'mock-user-id-12345'; // Fallback for mock
    }

    // 2. Load Target UID
    final prefs = await SharedPreferences.getInstance();
    _targetUserId = prefs.getString('target_uid');
    if (_targetUserId != null) {
      _targetUidController.text = _targetUserId!;
    }

    // 3. Fetch My Message & Listen for Updates
    if (_myUserId != null) {
      _fetchAndSyncMyMessage();
      _subscribeToMyMessage();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchAndSyncMyMessage() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('id', _myUserId!)
          .maybeSingle();

      if (data != null && data['content'] != null) {
        final content = data['content'] as String;
        await _updateLocalWidget(content);
      }
    } catch (e) {
      debugPrint('Error fetching my message: $e');
    }
  }

  void _subscribeToMyMessage() {
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('id', _myUserId!)
        .listen((List<Map<String, dynamic>> data) async {
          if (data.isNotEmpty && data.first['content'] != null) {
            final content = data.first['content'] as String;
            await _updateLocalWidget(content);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('New message received! Widget updated.')),
              );
            }
          }
        });
  }

  Future<void> _updateLocalWidget(String message) async {
    debugPrint('--- [Flutter] _updateLocalWidget Start ---');
    debugPrint('Message to save: "$message"');
    debugPrint('App Group ID: $appGroupId');
    
    try {
      await HomeWidget.saveWidgetData<String>('message_key', message);
      debugPrint('--- [Flutter] saveWidgetData Success ---');
      
      // Verify immediately
      final savedData = await HomeWidget.getWidgetData<String>('message_key');
      debugPrint('--- [Flutter] Verification Read: "$savedData" ---');

      await HomeWidget.updateWidget(
        name: widgetName,
        iOSName: widgetName,
      );
      debugPrint('--- [Flutter] updateWidget Called ---');
    } catch (e) {
      debugPrint('--- [Flutter] Error in _updateLocalWidget: $e ---');
    }
  }

  Future<void> _saveTargetUid() async {
    final uid = _targetUidController.text.trim();
    if (uid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_uid', uid);
    
    if (!mounted) return;

    setState(() {
      _targetUserId = uid;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target UID Saved')),
    );
  }

  Future<void> _sendMessage() async {
    if (_targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a Target UID first')),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 1. Update Supabase
      // Table: messages (id, content, updated_at)
      // We use the Target UID as the ID to update THEIR message record
      await Supabase.instance.client.from('messages').upsert({
        'id': _targetUserId,
        'content': message,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Update Local Widget (Optional: to show what I sent? 
      // Actually requirements say "update paired partner's widget".
      // But usually you might want to update your own widget to show "Last sent: ..." or similar.
      // The requirements say: "Update success -> hit home_widget -> update MY widget" (Step 2.4/Step 3)
      // Wait, Step 2 says: "Update success -> hit home_widget -> test if MY widget updates"
      // This implies we might be testing by sending to OURSELVES or the widget displays "Sent message".
      // Let's just save the data to the widget.
      
      await HomeWidget.saveWidgetData<String>('message_key', message);
      await HomeWidget.updateWidget(
        name: widgetName,
        iOSName: widgetName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message Sent & Widget Updated!')),
      );
      _messageController.clear();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Message Sync')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // My ID Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('My User ID', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SelectableText(
                            _myUserId ?? 'Unknown',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Target ID Section
                  TextField(
                    controller: _targetUidController,
                    decoration: const InputDecoration(
                      labelText: 'Target User ID',
                      border: OutlineInputBorder(),
                      helperText: 'Enter the UID of the person you want to message',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveTargetUid,
                    child: const Text('Save Target UID'),
                  ),

                  const Divider(height: 48),

                  // Message Section
                  Text(
                    'Send Message to Target',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      hintText: 'Hello from Flutter!',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Send to Widget'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // --- Auth & Profile ---

  User? get currentUser => _client.auth.currentUser;

  Future<void> signInAnonymously() async {
    if (currentUser == null) {
      await _client.auth.signInAnonymously();
    }
  }

  Future<void> updateProfile(String nickname) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'nickname': nickname,
      // 'updated_at': DateTime.now().toIso8601String(), // Column not in DB
    });
  }

  Future<String?> getNickname(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('nickname')
          .eq('id', userId)
          .single();
      return response['nickname'] as String?;
    } catch (e) {
      return null;
    }
  }

  // --- Tasks ---

  Stream<List<Task>> getTasksStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();

    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at')
        .map((data) => data.map((json) => _toTask(json)).toList());
  }
  
  Stream<List<Task>> getPartnerTasksStream(String partnerId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', partnerId)
        .order('created_at')
        .map((data) => data.map((json) => _toTask(json)).toList());
  }

  Future<void> addTask(String title, String? targetPartnerId) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('tasks').insert({
      'user_id': user.id,
      'title': title,
      'is_done': false,
      'target_partner_id': targetPartnerId,
      // 'created_at' is handled by default in DB
    });
  }

  Future<void> toggleTask(String taskId, bool isDone) async {
    await _client.from('tasks').update({
      'is_done': isDone,
      'done_at': isDone ? DateTime.now().toIso8601String() : null,
    }).eq('id', taskId);
  }

  // ... (other methods remain similar but ensure snake_case keys if needed)

  // Helper to convert Supabase JSON (snake_case) to Task
  Task _toTask(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isDone: json['is_done'] ?? false,
      doneAt: json['done_at'] != null ? DateTime.parse(json['done_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      // Reset config might not be in DB yet, handle gracefully
      targetPartnerId: json['target_partner_id'],
    );
  }

  Future<void> updateTaskTitle(String taskId, String newTitle) async {
    await _client.from('tasks').update({
      'title': newTitle,
    }).eq('id', taskId);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  // --- Partners ---

  Future<void> addPartner(String partnerId) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('partners').insert({
      'user_id': user.id,
      'partner_id': partnerId,
    });
  }

  Future<List<String>> getPartnerIds() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('partners')
        .select('partner_id')
        .eq('user_id', user.id);
    
    return (response as List).map((e) => e['partner_id'] as String).toList();
  }
}

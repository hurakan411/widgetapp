import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // --- Auth & Profile ---

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

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

  Future<List<Task>> getTasksOnce() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', user.id)
        .order('created_at');
    
    return (response as List).map((json) => _toTask(json)).toList();
  }
  
  Stream<List<Task>> getPartnerTasksStream(String partnerId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', partnerId)
        .order('created_at')
        .map((data) => data.map((json) => _toTask(json)).toList());
  }

  Future<List<Task>> getPartnerTasksOnce(String partnerId) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', partnerId)
        .order('created_at');
    
    return (response as List).map((json) => _toTask(json)).toList();
  }

  Future<void> addTask(String title, String? targetPartnerId, {ResetType resetType = ResetType.none, int? resetValue}) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('tasks').insert({
      'user_id': user.id,
      'title': title,
      'is_done': false,
      'target_partner_id': targetPartnerId,
      'reset_type': resetType == ResetType.none ? null : resetType.name,
      'reset_value': resetValue,
    });
  }

  Future<void> toggleTask(String taskId, bool isDone) async {
    await _client.from('tasks').update({
      'is_done': isDone,
      'done_at': isDone ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', taskId);
  }

  Future<void> updateTask(String taskId, {String? title, ResetType? resetType, int? resetValue}) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (resetType != null) updates['reset_type'] = resetType == ResetType.none ? null : resetType.name;
    if (resetValue != null) updates['reset_value'] = resetValue;
    
    if (updates.isNotEmpty) {
      await _client.from('tasks').update(updates).eq('id', taskId);
    }
  }

  Future<void> confirmTask(String taskId) async {
    // When confirmed by partner, mark as confirmed with timestamp
    try {
      await _client.from('tasks').update({
        'is_confirmed': true,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', taskId);
      print('[confirmTask] Success for $taskId');
    } catch (e) {
      print('[confirmTask] Error: $e');
    }
  }

  Future<void> unconfirmTask(String taskId) async {
    // Remove confirmation but keep task as done
    await _client.from('tasks').update({
      'is_confirmed': false,
      'confirmed_at': null,
    }).eq('id', taskId);
  }

  // Helper to convert Supabase JSON (snake_case) to Task
  Task _toTask(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isDone: json['is_done'] ?? false,
      doneAt: json['done_at'] != null ? DateTime.parse(json['done_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      targetPartnerId: json['target_partner_id'],
      isConfirmed: json['is_confirmed'] ?? false,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
      resetType: _parseResetType(json['reset_type']),
      resetValue: json['reset_value'],
    );
  }

  ResetType _parseResetType(String? type) {
    if (type == 'daily') return ResetType.daily;
    if (type == 'interval') return ResetType.interval;
    return ResetType.none;
  }

  Future<void> updateTaskTitle(String taskId, String newTitle) async {
    await updateTask(taskId, title: newTitle);
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

  Future<void> removePartner(String partnerId) async {
    final user = currentUser;
    if (user == null) {
      print('[removePartner] No user logged in');
      return;
    }

    print('[removePartner] Removing partner: $partnerId for user: ${user.id}');
    
    try {
      await _client
          .from('partners')
          .delete()
          .eq('user_id', user.id)
          .eq('partner_id', partnerId);
      print('[removePartner] Delete successful');
    } catch (e) {
      print('[removePartner] Error: $e');
    }
  }

  Future<List<String>> getPartnerIds() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('partners')
        .select('partner_id')
        .eq('user_id', user.id);
    
    final ids = (response as List).map((e) => e['partner_id'] as String).toList();
    print('[getPartnerIds] Found ${ids.length} partners: $ids');
    return ids;
  }

  Future<void> checkAndResetDailyTasks() async {
    final user = currentUser;
    if (user == null) return;

    // Fetch done tasks with daily reset
    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', user.id)
        .eq('is_done', true)
        .eq('reset_type', 'daily');

    final tasks = (response as List).map((json) => _toTask(json)).toList();
    final now = DateTime.now();

    for (final task in tasks) {
      if (task.resetValue == null || task.doneAt == null) continue;

      final hour = task.resetValue! ~/ 100;
      final minute = task.resetValue! % 100;
      
      // Today's reset time (Local)
      final resetTimeToday = DateTime(now.year, now.month, now.day, hour, minute);
      final doneAtLocal = task.doneAt!.toLocal();
      
      print("[DailyReset] Task: ${task.title}, DoneAt: $doneAtLocal, ResetTime: $resetTimeToday");
      
      // If now is past reset time
      if (now.isAfter(resetTimeToday)) {
        // If doneAt is before reset time, it means it was done in the previous cycle
        if (doneAtLocal.isBefore(resetTimeToday)) {
          print("[DailyReset] Resetting ${task.title} (Reason: Done before today's reset time)");
          await resetTaskStatus(task.id);
        }
      } else {
        // If now is before reset time (e.g. 02:00, reset at 04:00)
        final resetTimeYesterday = resetTimeToday.subtract(const Duration(days: 1));
        if (now.isAfter(resetTimeYesterday)) {
             if (doneAtLocal.isBefore(resetTimeYesterday)) {
                print("[DailyReset] Resetting ${task.title} (Reason: Done before yesterday's reset time)");
                await resetTaskStatus(task.id);
             }
        }
      }
    }
  }

  Future<void> resetTaskStatus(String taskId) async {
    await _client.from('tasks').update({
      'is_done': false,
      'is_confirmed': false,
      'done_at': null,
    }).eq('id', taskId);
  }
}

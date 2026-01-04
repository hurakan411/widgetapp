import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'constants/config.dart';
import 'constants/design.dart';
import 'models/task.dart';
import 'services/supabase_service.dart';
import 'widgets/background_pattern.dart';
import 'widgets/neumorphic_task_card.dart';
import 'widgets/progress_header.dart';

// Placeholder credentials
const String appGroupId = 'group.com.shashinoguchi.widgetTask';
const String iOSWidgetName = 'MessageWidget';

// Keys
const String partnerTasksKey = 'partner_tasks_key';
const String partnerIdKey = 'partner_user_id';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  await HomeWidget.setAppGroupId(appGroupId);
  runApp(const OmamoriApp());
}

class OmamoriApp extends StatelessWidget {
  const OmamoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMAMORI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.vintageNavy,
        fontFamily: 'Helvetica Neue',
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Partner Management
  List<String> _partnerIds = [];
  Map<String, String> _partnerNames = {}; // ID -> Nickname

  // Service
  final _supabaseService = SupabaseService();
  
  Stream<List<Task>>? _myTasksStream;
  final Set<String> _deletingTaskIds = {}; // Track tasks currently animating out
  final Set<String> _confirmedTaskIds = {}; // Track tasks optimistically confirmed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSupabase();
    // Setup widget
    HomeWidget.setAppGroupId(appGroupId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _supabaseService.checkAndResetDailyTasks();
      setState(() {
        _myTasksStream = _supabaseService.getTasksStream();
      });
      _syncToWidget();
    }
  }

  Future<void> _initializeSupabase() async {
    await _supabaseService.signInAnonymously();
    
    // Ensure profile exists
    final user = _supabaseService.currentUser;
    if (user != null) {
      // Check if nickname exists, if not set default
      final nickname = await _supabaseService.getNickname(user.id);
      if (nickname == null) {
        await _supabaseService.updateProfile("User_${user.id.substring(0, 4)}");
      }
      
      // Check and reset daily tasks
      await _supabaseService.checkAndResetDailyTasks();
      
      // Initialize Stream
      setState(() {
        _myTasksStream = _supabaseService.getTasksStream();
      });
    }

    await _loadPartners();
    _syncToWidget();
  }

  Future<void> _loadPartners() async {
    // Load partners from Supabase
    final ids = await _supabaseService.getPartnerIds();
    final prefs = await SharedPreferences.getInstance();
    
    Map<String, String> names = {};
    for (var id in ids) {
      // Check local nickname first
      String? name = prefs.getString('partner_nickname_$id');
      
      if (name == null) {
        // Fallback to Supabase profile nickname
        name = await _supabaseService.getNickname(id);
      }
      
      names[id] = name ?? "Partner";
    }

    setState(() {
      _partnerIds = ids;
      _partnerNames = names;
    });
  }

  // --- Task Operations (Supabase) ---

  Future<void> _addTask(String title, String? targetPartnerId, ResetType resetType, int? resetValue) async {
    await _supabaseService.addTask(title, targetPartnerId, resetType: resetType, resetValue: resetValue);
    _updateWidget();
  }

  Future<void> _deleteTask(String taskId) async {
    await _supabaseService.deleteTask(taskId);
    setState(() {
      _myTasksStream = _supabaseService.getTasksStream();
    });
    _updateWidget();
  }

  Future<void> _toggleTask(Task task, bool isPartnerPage) async {
    // First, check if task is Confirmed
    if (task.isConfirmed) {
      // Confirmed -> Done (just remove confirmation)
      setState(() {
        _confirmedTaskIds.remove(task.id);
      });
      
      try {
        await _supabaseService.unconfirmTask(task.id);
      } catch (e) {
        print("Error undoing confirmation: $e");
      }
    } else if (!isPartnerPage) {
      // My Task (Not Confirmed): Toggle Done/Undone
      await _supabaseService.toggleTask(task.id, !task.isDone);
    } else {
      // Partner's Task (Not Confirmed)
      if (task.isDone) {
        // Done -> Confirmed
        setState(() {
          _confirmedTaskIds.add(task.id);
        });
        
        try {
          await _supabaseService.confirmTask(task.id);
        } catch (e) {
          print("Error confirming task: $e");
          setState(() {
            _confirmedTaskIds.remove(task.id); // Revert if failed
          });
        }
      }
      // If partner hasn't finished (task.isDone == false), do nothing
    }
    
    // Refresh stream
    setState(() {
      _myTasksStream = _supabaseService.getTasksStream();
    });
    
    // Wait a bit for DB propagation before syncing widget
    await Future.delayed(const Duration(milliseconds: 500));
    _updateWidget();
  }

  Future<void> _editTask(String taskId, String newTitle, ResetType resetType, int? resetValue) async {
    await _supabaseService.updateTask(taskId, title: newTitle, resetType: resetType, resetValue: resetValue);
    _updateWidget();
  }


  void _updateWidget() {
    // Sync logic for widget needs to be adapted for Supabase data.
    // Since we don't have local list readily available here without stream,
    // we might need to fetch latest tasks to update widget.
    // For now, let's leave this placeholder or implement a fetch.
    // Ideally, the widget should fetch from Supabase directly or we sync periodically.
    // Given the widget code uses UserDefaults, we should fetch and save to UserDefaults.
    _syncToWidget();
  }

  Future<void> _syncToWidget() async {
    // Helper to calculate scheduledResetAt
    Task updateTaskForWidget(Task task) {
      Task t = task;
      // Apply optimistic confirmation
      if (_confirmedTaskIds.contains(t.id)) {
        t = t.copyWith(isConfirmed: true);
      }

      if (t.resetType == ResetType.daily && t.resetValue != null) {
        final now = DateTime.now();
        final hour = t.resetValue! ~/ 100;
        final minute = t.resetValue! % 100;
        
        DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        
        if (now.isAfter(scheduled)) {
          // Already passed today's reset time, so next is tomorrow
          scheduled = scheduled.add(const Duration(days: 1));
        }
        
        return t.copyWith(scheduledResetAt: scheduled);
      }
      return t;
    }
    
    // Save Supabase Credentials for Widget
    await HomeWidget.saveWidgetData('supabase_url', AppConfig.supabaseUrl);
    await HomeWidget.saveWidgetData('supabase_anon_key', AppConfig.supabaseAnonKey);
    final session = _supabaseService.currentSession;
    if (session != null) {
      await HomeWidget.saveWidgetData('supabase_access_token', session.accessToken);
    }

    // Fetch my tasks
    final myTasks = await _supabaseService.getTasksOnce();
    
    final myTasksForWidget = myTasks.map((t) => updateTaskForWidget(t)).toList();
    
    await HomeWidget.saveWidgetData(
      'my_tasks_key',
      jsonEncode(myTasksForWidget.map((t) => t.toJson()).toList()),
    );
    
    // Fetch partner tasks
    for (int i = 0; i < _partnerIds.length; i++) {
      final pid = _partnerIds[i];
      final pTasks = await _supabaseService.getPartnerTasksOnce(pid);
      
      final pTasksForWidget = pTasks.map((t) => updateTaskForWidget(t)).toList();
      
      await HomeWidget.saveWidgetData(
        'partner_tasks_key_$i',
        jsonEncode(pTasksForWidget.map((t) => t.toJson()).toList()),
      );
    }

    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
    );
    print("--- Synced All Tasks to Widget ---");
  }

  // --- UI Helpers ---

  void _showTaskDialog({String? partnerId, Task? taskToEdit}) {
    final isEditing = taskToEdit != null;
    final controller = TextEditingController(text: taskToEdit?.title ?? '');
    String? selectedTargetPartner = isEditing ? taskToEdit.targetPartnerId : partnerId;
    ResetType resetType = taskToEdit?.resetType ?? ResetType.none;
    
    int? resetValue = taskToEdit?.resetValue;
    TimeOfDay resetTime = resetValue != null 
        ? TimeOfDay(hour: resetValue ~/ 100, minute: resetValue % 100)
        : const TimeOfDay(hour: 4, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AppStyles.neumorphicConvex.copyWith(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      isEditing ? 'タスク編集' : '新規タスク',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Task Name Input (Concave)
                    Container(
                      decoration: AppStyles.neumorphicConcave.copyWith(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'タスク名を入力',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reset Type (Convex)
                    Container(
                      decoration: AppStyles.neumorphicConvex.copyWith(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<ResetType>(
                          value: resetType,
                          decoration: const InputDecoration(
                            labelText: "ルーティン設定",
                            labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            border: InputBorder.none,
                          ),
                          items: const [
                            DropdownMenuItem(value: ResetType.none, child: Text("なし（一回限り）")),
                            DropdownMenuItem(value: ResetType.daily, child: Text("毎日繰り返す")),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              resetType = val!;
                              if (resetType != ResetType.none) {
                                // Set default reset value if not set
                                if (resetValue == null) {
                                  resetValue = 400; // 04:00
                                  resetTime = const TimeOfDay(hour: 4, minute: 0);
                                }
                              } else {
                                resetValue = null;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reset Time Picker (Only if Daily)
                    if (resetType == ResetType.daily) ...[
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: resetTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              resetTime = picked;
                              resetValue = picked.hour * 100 + picked.minute;
                            });
                          }
                        },
                        child: Container(
                          decoration: AppStyles.neumorphicConvex.copyWith(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("リセット時間", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              Text(
                                "${resetTime.hour.toString().padLeft(2, '0')}:${resetTime.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Partner Selection
                    if ((partnerId == null || isEditing) && _partnerIds.isNotEmpty) ...[
                      Container(
                        decoration: AppStyles.neumorphicConvex.copyWith(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: selectedTargetPartner,
                            decoration: const InputDecoration(
                              labelText: "パートナーと共有",
                              labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              border: InputBorder.none,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null, 
                                child: Text(
                                  "指定なし（全員に公開 / 自分のみ）",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ..._partnerIds.map((pid) => DropdownMenuItem(
                                value: pid,
                                child: Text(
                                  _partnerNames[pid] ?? pid,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedTargetPartner = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Actions
                    Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _deleteTask(taskToEdit!.id);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: AppStyles.neumorphicConvex.copyWith(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.background,
                                ),
                                child: const Center(
                                  child: Text('削除', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: AppStyles.neumorphicConvex.copyWith(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.background,
                              ),
                              child: const Center(
                                child: Text('キャンセル', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (controller.text.isNotEmpty) {
                                if (isEditing) {
                                  _editTask(taskToEdit!.id, controller.text, resetType, resetValue);
                                } else {
                                  _addTask(controller.text, selectedTargetPartner, resetType, resetValue);
                                }
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: AppStyles.neumorphicConvex.copyWith(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.background,
                              ),
                              child: Center(
                                child: Text(
                                  isEditing ? '保存' : '追加',
                                  style: const TextStyle(color: AppColors.vintageNavy, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
  
  String _getResetLabel(ResetType type, int? value) {
    if (type == ResetType.interval) {
      if (value == 60) return "1 Hour After Done";
      if (value == 180) return "3 Hours After Done";
      if (value == 360) return "6 Hours After Done";
      if (value == 720) return "12 Hours After Done";
      if (value == 1440) return "24 Hours After Done";
    }
    return "None";
  }

  void _showPartnerManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final idController = TextEditingController();
          final nameController = TextEditingController();
          
          return AlertDialog(
            backgroundColor: AppColors.background,
            title: const Text('Manage Partners', style: TextStyle(color: AppColors.textPrimary)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_partnerIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No partners added yet.", style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _partnerIds.length,
                      itemBuilder: (context, index) {
                        final pid = _partnerIds[index];
                        final name = _partnerNames[pid] ?? "No Name";
                        return ListTile(
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("ID: ${pid.substring(0, 8)}..."),
                          onTap: () {},
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  if (_partnerIds.length < 3) ...[
                    const Divider(),
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: 'Partner ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nickname (Optional)',
                        hintText: 'e.g. Mom',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.vintageNavy),
                      onPressed: () async {
                        if (idController.text.isNotEmpty) {
                          if (_partnerIds.contains(idController.text)) {
                            return;
                          }
                          
                          try {
                            // Add partner via Supabase
                            await _supabaseService.addPartner(idController.text);
                            
                            // Save nickname locally if provided
                            if (nameController.text.isNotEmpty) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('partner_nickname_${idController.text}', nameController.text);
                            }

                            // Reload partners
                            await _loadPartners();
                            
                            setDialogState(() {
                              idController.clear();
                              nameController.clear();
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('無効なPartner IDです。')),
                            );
                          }
                        }
                      },
                      child: const Text('Add Partner', style: TextStyle(color: Colors.white)),
                    ),
                  ] else
                    const Text("Max 3 partners reached.", style: TextStyle(color: AppColors.terracotta, fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          );
        }
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    return "${months[now.month - 1]} ${now.day}";
  }

  Widget _buildTaskPage({
    required String title,
    required String subtitle,
    required String? partnerId,
    required Color accentColor,
    required IconData icon,
    bool isPartnerPage = false,
  }) {
    final stream = isPartnerPage 
        ? _supabaseService.getPartnerTasksStream(partnerId!) 
        : (_myTasksStream ?? const Stream.empty());

    return StreamBuilder<List<Task>>(
      stream: stream,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        
        // Calculate Progress
        double progress = 0.0;
        if (tasks.isNotEmpty) {
          int doneCount = tasks.where((t) => t.isDone).length;
          progress = doneCount / tasks.length;
        }

        return Column(
          children: [
            // Progress Header
            ProgressHeader(
              title: title,
              subtitle: subtitle,
              progress: progress,
              accentColor: accentColor,
              icon: icon,
            ),
            
            // Task List
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt, size: 60, color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            "No tasks yet.",
                            style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _supabaseService.checkAndResetDailyTasks();
                        setState(() {
                           // Re-trigger stream if needed, though stream updates automatically
                           if (isPartnerPage) {
                             // No need to re-assign stream for partner page as it's created in build
                           } else {
                             _myTasksStream = _supabaseService.getTasksStream();
                           }
                        });
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          var task = tasks[index];
                          if (_confirmedTaskIds.contains(task.id)) {
                            task = task.copyWith(isConfirmed: true);
                          }
                          final isDeleting = _deletingTaskIds.contains(task.id);
                          return AnimatedCrossFade(
                            duration: const Duration(milliseconds: 1500),
                            firstChild: NeumorphicTaskCard(
                              task: task,
                              onTap: () => _toggleTask(task, isPartnerPage),
                              onEdit: () => _showTaskDialog(partnerId: partnerId, taskToEdit: task),
                              partnerName: task.targetPartnerId != null ? _partnerNames[task.targetPartnerId] : null,
                              isReadOnly: isPartnerPage,
                            ),
                            secondChild: const SizedBox(width: double.infinity, height: 0),
                            crossFadeState: isDeleting ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      }
    );
  }

  DateTime? _lastSnackBarTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BackgroundPattern(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar (Logo & Indicator)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final now = DateTime.now();
                        if (_lastSnackBarTime != null && 
                            now.difference(_lastSnackBarTime!) < const Duration(seconds: 1)) {
                          return;
                        }

                        final userId = _supabaseService.currentUser?.id;
                        if (userId != null) {
                          Clipboard.setData(ClipboardData(text: userId));
                          _lastSnackBarTime = now;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('IDがコピーされました！'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OMAMORI',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (_supabaseService.currentUser != null)
                            Text(
                              "ID: ${_supabaseService.currentUser!.id.substring(0, 8)}...",
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Page Indicator
                    Row(
                      children: List.generate(1 + _partnerIds.length + (_partnerIds.length < 3 ? 1 : 0), (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _buildDot(index),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              
              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    // Page 0: My Tasks
                  _buildTaskPage(
                    title: "MY TASKS",
                    subtitle: _getFormattedDate(),
                    partnerId: null,
                    accentColor: AppColors.vintageNavy,
                    icon: Icons.person,
                  ),
                  
                  // Partner Pages
                  ..._partnerIds.map((pid) => _buildTaskPage(
                    title: _partnerNames[pid] ?? "PARTNER",
                    subtitle: "PARTNER'S TASKS",
                    partnerId: pid,
                    accentColor: AppColors.terracotta,
                    isPartnerPage: true,
                    icon: Icons.favorite,
                  )).toList(),

                  // Add Partner Page (if less than 3 partners)
                  if (_partnerIds.length < 3)
                    _buildAddPartnerPage(),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
          boxShadow: AppStyles.neumorphicConvex.boxShadow,
        ),
        child: FloatingActionButton(
          onPressed: () {
            String? currentPartnerId;
            if (_currentPage > 0 && _partnerIds.isNotEmpty) {
              // Adjust index because page 0 is My Tasks
              int pIndex = _currentPage - 1;
              if (pIndex < _partnerIds.length) {
                currentPartnerId = _partnerIds[pIndex];
              }
            }
            _showTaskDialog(partnerId: currentPartnerId);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: AppColors.textPrimary, size: 32),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.vintageNavy : AppColors.textSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
  
  Widget _buildAddPartnerPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add, size: 60, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            _partnerIds.isEmpty ? "No Partner Set" : "Add Another Partner",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.vintageNavy,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: _showPartnerManagementDialog,
            child: const Text("Add Partner", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

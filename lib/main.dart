import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'constants/design.dart';
import 'models/task.dart';
import 'widgets/neumorphic_task_card.dart';

// Placeholder credentials
const String appGroupId = 'group.com.shashinoguchi.widgetTask';
const String widgetName = 'MessageWidget';

// Keys
const String myTasksKey = 'my_tasks_key';
const String partnerTasksKey = 'partner_tasks_key';
const String partnerIdKey = 'partner_user_id';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data
  List<Task> _myTasks = [];
  // Map partner ID to their task list
  Map<String, List<Task>> _partnerTasksMap = {};
  List<String> _partnerIds = [];
  Map<String, String> _partnerNames = {}; // Map ID to Nickname
  
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _partnerIds = prefs.getStringList('partner_ids') ?? [];
      // Load names
      String? namesJson = prefs.getString('partner_names');
      if (namesJson != null) {
        _partnerNames = Map<String, String>.from(jsonDecode(namesJson));
      }
    });

    // Load My Tasks (Mock)
    if (_myTasks.isEmpty) {
      setState(() {
        _myTasks = [
          Task(id: _uuid.v4(), title: 'Morning Medicine', createdAt: DateTime.now(), resetType: ResetType.daily, resetValue: 400),
          Task(id: _uuid.v4(), title: 'Lock the Door', createdAt: DateTime.now()),
        ];
      });
    }

    // Load Partner Tasks (Mock for each partner)
    for (String pid in _partnerIds) {
      if (!_partnerTasksMap.containsKey(pid)) {
        _partnerTasksMap[pid] = [
          Task(id: _uuid.v4(), title: 'Partner Task 1', createdAt: DateTime.now()),
          Task(id: _uuid.v4(), title: 'Partner Task 2', createdAt: DateTime.now()),
        ];
      }
    }
    
    _checkAndResetTasks(); // Check for expired tasks
    _syncWidget();
  }

  Future<void> _updatePartners(List<String> newIds, Map<String, String> newNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('partner_ids', newIds);
    await prefs.setString('partner_names', jsonEncode(newNames));
    
    setState(() {
      _partnerIds = newIds;
      _partnerNames = newNames;
      
      // Initialize task list for new partners if needed
      for (String pid in newIds) {
        if (!_partnerTasksMap.containsKey(pid)) {
          _partnerTasksMap[pid] = [];
        }
      }
      // Cleanup removed partners
      _partnerTasksMap.removeWhere((key, value) => !newIds.contains(key));
    });
    _syncWidget();
  }

  // Check if any done tasks should be reset
  void _checkAndResetTasks() {
    final now = DateTime.now();
    bool changed = false;

    void checkList(List<Task> list) {
      for (int i = 0; i < list.length; i++) {
        final task = list[i];
        if (task.isDone && task.scheduledResetAt != null && now.isAfter(task.scheduledResetAt!)) {
          list[i] = task.copyWith(
            isDone: false,
            doneAt: null,
            scheduledResetAt: null,
          );
          changed = true;
          debugPrint('Task "${task.title}" auto-reset.');
        }
      }
    }

    checkList(_myTasks);
    _partnerTasksMap.values.forEach(checkList);

    if (changed) {
      setState(() {});
      _syncWidget();
    }
  }

  // --- Task Management ---

  void _addTask(String title, String? partnerId, ResetType resetType, int? resetValue, String? targetPartnerId) {
    final newTask = Task(
      id: _uuid.v4(),
      title: title,
      createdAt: DateTime.now(),
      resetType: resetType,
      resetValue: resetValue,
      targetPartnerId: targetPartnerId,
    );

    setState(() {
      if (partnerId != null) {
        if (_partnerTasksMap.containsKey(partnerId)) {
          _partnerTasksMap[partnerId]!.add(newTask);
        }
      } else {
        _myTasks.add(newTask);
      }
    });
    _syncWidget();
  }

  void _editTask(String id, String? partnerId, String newTitle, ResetType newResetType, int? newResetValue, String? newTargetPartnerId) {
    setState(() {
      final list = partnerId != null ? _partnerTasksMap[partnerId] : _myTasks;
      if (list != null) {
        final index = list.indexWhere((t) => t.id == id);
        if (index != -1) {
          final oldTask = list[index];
          list[index] = oldTask.copyWith(
            title: newTitle,
            resetType: newResetType,
            resetValue: newResetValue,
            targetPartnerId: newTargetPartnerId,
          );
        }
      }
    });
    _syncWidget();
  }

  void _toggleTask(String id, String? partnerId) {
    setState(() {
      final list = partnerId != null ? _partnerTasksMap[partnerId] : _myTasks;
      if (list != null) {
        final index = list.indexWhere((t) => t.id == id);
        if (index != -1) {
          final task = list[index];
          final newIsDone = !task.isDone;
          DateTime? nextReset;

          if (newIsDone) {
            final now = DateTime.now();
            if (task.resetType == ResetType.interval && task.resetValue != null) {
              // Reset after X minutes
              nextReset = now.add(Duration(minutes: task.resetValue!));
            } else if (task.resetType == ResetType.daily && task.resetValue != null) {
              // Reset at specific time (e.g. 0400)
              final hour = task.resetValue! ~/ 100;
              final minute = task.resetValue! % 100;
              var target = DateTime(now.year, now.month, now.day, hour, minute);
              if (target.isBefore(now)) {
                target = target.add(const Duration(days: 1));
              }
              nextReset = target;
            }
          }

          list[index] = task.copyWith(
            isDone: newIsDone,
            doneAt: newIsDone ? DateTime.now() : null,
            scheduledResetAt: nextReset,
          );
        }
      }
    });
    _syncWidget();
  }

  Future<void> _syncWidget() async {
    try {
      final myJson = jsonEncode(_myTasks.map((t) => t.toJson()).toList());
      await HomeWidget.saveWidgetData<String>(myTasksKey, myJson);
      
      // Save each partner's tasks and name with a specific key index
      for (int i = 0; i < 3; i++) {
        String key = 'partner_tasks_key_$i';
        String nameKey = 'partner_name_key_$i';
        
        if (i < _partnerIds.length) {
          String pid = _partnerIds[i];
          List<Task> tasks = _partnerTasksMap[pid] ?? [];
          String name = _partnerNames[pid] ?? "Partner ${i + 1}";
          
          final pJson = jsonEncode(tasks.map((t) => t.toJson()).toList());
          await HomeWidget.saveWidgetData<String>(key, pJson);
          await HomeWidget.saveWidgetData<String>(nameKey, name);
        } else {
          // Clear unused keys
          await HomeWidget.saveWidgetData<String>(key, "[]");
          await HomeWidget.saveWidgetData<String>(nameKey, "");
        }
      }

      await HomeWidget.updateWidget(name: widgetName, iOSName: widgetName);
      debugPrint('--- Synced All Tasks to Widget ---');
    } catch (e) {
      debugPrint('Error syncing widget: $e');
    }
  }

  // --- UI Helpers ---

  void _showTaskDialog({required String? partnerId, Task? taskToEdit}) {
    final isEditing = taskToEdit != null;
    final controller = TextEditingController(text: taskToEdit?.title ?? '');
    
    ResetType selectedType = taskToEdit?.resetType ?? ResetType.none;
    int? selectedValue = taskToEdit?.resetValue;
    String? selectedTargetPartner = taskToEdit?.targetPartnerId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(
              isEditing ? 'Edit Task' : (partnerId != null ? 'New Task for ${_partnerNames[partnerId] ?? "Partner"}' : 'New Task for Me'),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Task Name',
                      hintText: 'e.g. Water Plants',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Target Partner Selection (Only for My Tasks)
                  if (partnerId == null && _partnerIds.isNotEmpty) ...[
                    const Text("Share with Partner:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    DropdownButton<String?>(
                      value: selectedTargetPartner,
                      isExpanded: true,
                      hint: const Text("Select Partner (Optional)"),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("None (Private / All)")),
                        ..._partnerIds.map((pid) => DropdownMenuItem(
                          value: pid,
                          child: Text(_partnerNames[pid] ?? pid),
                        )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedTargetPartner = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text("Auto Reset Rule:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _getResetLabel(selectedType, selectedValue),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: "None", child: Text("None (Manual Reset)")),
                      const DropdownMenuItem(value: "1 Hour After Done", child: Text("1 Hour After Done")),
                      const DropdownMenuItem(value: "3 Hours After Done", child: Text("3 Hours After Done")),
                      const DropdownMenuItem(value: "6 Hours After Done", child: Text("6 Hours After Done")),
                      const DropdownMenuItem(value: "12 Hours After Done", child: Text("12 Hours After Done")),
                      const DropdownMenuItem(value: "24 Hours After Done", child: Text("24 Hours After Done")),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == "1 Hour After Done") {
                          selectedType = ResetType.interval;
                          selectedValue = 60;
                        } else if (value == "3 Hours After Done") {
                          selectedType = ResetType.interval;
                          selectedValue = 180;
                        } else if (value == "6 Hours After Done") {
                          selectedType = ResetType.interval;
                          selectedValue = 360;
                        } else if (value == "12 Hours After Done") {
                          selectedType = ResetType.interval;
                          selectedValue = 720;
                        } else if (value == "24 Hours After Done") {
                          selectedType = ResetType.interval;
                          selectedValue = 1440;
                        } else {
                          selectedType = ResetType.none;
                          selectedValue = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.vintageNavy),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    if (isEditing) {
                      _editTask(taskToEdit!.id, partnerId, controller.text, selectedType, selectedValue, selectedTargetPartner);
                    } else {
                      _addTask(controller.text, partnerId, selectedType, selectedValue, selectedTargetPartner);
                    }
                    Navigator.pop(context);
                  }
                },
                child: Text(isEditing ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
              ),
            ],
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
                          subtitle: Text("ID: $pid"),
                          onTap: () {
                            // Edit Name Dialog
                            final editNameController = TextEditingController(text: name);
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Edit Nickname"),
                                content: TextField(
                                  controller: editNameController,
                                  decoration: const InputDecoration(labelText: "Nickname"),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        final newNames = Map<String, String>.from(_partnerNames);
                                        newNames[pid] = editNameController.text;
                                        _updatePartners(_partnerIds, newNames);
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Save"),
                                  )
                                ],
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                final newIds = List<String>.from(_partnerIds);
                                final newNames = Map<String, String>.from(_partnerNames);
                                newIds.removeAt(index);
                                newNames.remove(pid);
                                _updatePartners(newIds, newNames);
                              });
                            },
                          ),
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
                        labelText: 'Nickname',
                        hintText: 'e.g. Mom, John',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.vintageNavy),
                      onPressed: () {
                        if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                          if (_partnerIds.contains(idController.text)) {
                            // Duplicate check
                            return;
                          }
                          setDialogState(() {
                            final newIds = List<String>.from(_partnerIds);
                            final newNames = Map<String, String>.from(_partnerNames);
                            
                            newIds.add(idController.text);
                            newNames[idController.text] = nameController.text;
                            
                            _updatePartners(newIds, newNames);
                            idController.clear();
                            nameController.clear();
                          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'OMAMORI',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  // Page Indicator
                  Row(
                    children: List.generate(1 + (_partnerIds.isEmpty ? 1 : _partnerIds.length), (index) {
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
                    tasks: _myTasks,
                    partnerId: null,
                    icon: Icons.person,
                    color: AppColors.vintageNavy,
                  ),
                  
                  // Partner Pages
                  if (_partnerIds.isEmpty)
                    _buildEmptyPartnerPage()
                  else
                    ..._partnerIds.map((pid) => _buildTaskPage(
                      title: _partnerNames[pid]?.toUpperCase() ?? "PARTNER",
                      tasks: _partnerTasksMap[pid] ?? [],
                      partnerId: pid,
                      icon: Icons.favorite,
                      color: AppColors.terracotta,
                      isPartnerPage: true,
                    )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: AppStyles.neumorphicConvex.copyWith(borderRadius: BorderRadius.circular(30)),
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
          backgroundColor: AppColors.background,
          elevation: 0,
          child: const Icon(Icons.add, color: AppColors.textPrimary, size: 30),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 10,
      width: _currentPage == index ? 20 : 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? AppColors.vintageNavy : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildTaskPage({
    required String title,
    required List<Task> tasks,
    required String? partnerId,
    required IconData icon,
    required Color color,
    bool isPartnerPage = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.7),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (isPartnerPage)
                IconButton(
                  icon: const Icon(Icons.settings, size: 18, color: AppColors.textSecondary),
                  onPressed: _showPartnerManagementDialog,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return NeumorphicTaskCard(
                task: task,
                onTap: () => _toggleTask(task.id, partnerId),
                onEdit: () => _showTaskDialog(partnerId: partnerId, taskToEdit: task),
                partnerName: task.targetPartnerId != null ? _partnerNames[task.targetPartnerId] : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPartnerPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 60, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text(
            "No Partner Set",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
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

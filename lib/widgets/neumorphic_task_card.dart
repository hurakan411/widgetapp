import 'package:flutter/material.dart';
import '../models/task.dart';
import '../constants/design.dart';

class NeumorphicTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final String? partnerName;
  final bool isReadOnly;

  const NeumorphicTaskCard({
    Key? key,
    required this.task,
    required this.onTap,
    required this.onEdit,
    this.partnerName,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: task.isDone ? AppStyles.neumorphicConcave : AppStyles.neumorphicConvex,
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                boxShadow: task.isDone
                    ? [] // No shadow when done (pressed)
                    : [
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(2, 2),
                          blurRadius: 3,
                        ),
                      ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 16, color: AppColors.vintageNavy)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Title & Status Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      // Revert to primary text color, slightly dimmed if done
                      color: task.isDone ? AppColors.textPrimary.withOpacity(0.5) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (partnerName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.share, size: 12, color: AppColors.terracotta),
                          const SizedBox(width: 4),
                          Text(
                            "For: $partnerName",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.terracotta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (task.isDone && task.doneAt != null)
                    Text(
                      "DONE ${task.doneAt!.hour.toString().padLeft(2, '0')}:${task.doneAt!.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.vintageNavy.withOpacity(0.7),
                        letterSpacing: 1.0,
                      ),
                    )
                  else
                    Text(
                      isReadOnly ? "VIEW ONLY" : "TAP TO DONE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary.withOpacity(0.5),
                        letterSpacing: 1.0,
                      ),
                    ),
                ],
              ),
            ),

            // Edit Button (Hide if ReadOnly)
            if (!isReadOnly)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    // Add subtle shadow for visibility
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-2, -2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

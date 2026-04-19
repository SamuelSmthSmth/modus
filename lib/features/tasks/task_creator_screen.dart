import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../timer/home_screen.dart';
import 'task_provider.dart';

class TaskCreatorScreen extends StatefulWidget {
  const TaskCreatorScreen({super.key});

  @override
  State<TaskCreatorScreen> createState() => _TaskCreatorScreenState();
}

class _TaskCreatorScreenState extends State<TaskCreatorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final List<TaskPhase> _phases = [];

  @override
  void initState() {
    super.initState();
    final routine = context.read<TaskProvider>().activeTask;
    _titleController.text = routine.title;
    _phases.addAll(routine.phases);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSaveRoutine => true;

  String _formatMinutes(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  void _movePhaseUp(int index) {
    if (index <= 0) return;
    setState(() {
      final phase = _phases.removeAt(index);
      _phases.insert(index - 1, phase);
    });
  }

  void _movePhaseDown(int index) {
    if (index >= _phases.length - 1) return;
    setState(() {
      final phase = _phases.removeAt(index);
      _phases.insert(index + 1, phase);
    });
  }

  void _removePhase(int index) {
    setState(() {
      _phases.removeAt(index);
    });
  }

  Future<void> _importFromCSV() async {
    final errorMessage = await context
        .read<TaskProvider>()
        .importRoutineFromCSV();
    if (!mounted) return;

    if (errorMessage == null) {
      // Success
      final routine = context.read<TaskProvider>().activeTask;
      setState(() {
        _phases.clear();
        _phases.addAll(routine.phases);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Routine imported successfully (${routine.phases.length} phases)',
          ),
          backgroundColor: Colors.green[600],
        ),
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showAddPhaseDialog() async {
    final nameController = TextEditingController();
    final minutesController = TextEditingController();

    final result = await showDialog<TaskPhase>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Add Phase',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: const InputDecoration(labelText: 'Phase name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final minutes = int.tryParse(minutesController.text.trim());

                if (name.isEmpty || minutes == null || minutes <= 0) {
                  return;
                }

                Navigator.of(context).pop(
                  TaskPhase(
                    name: name,
                    duration: Duration(minutes: minutes),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    minutesController.dispose();

    if (result == null) return;

    setState(() {
      _phases.add(result);
    });
  }

  void _resetRoutine() {
    setState(() {
      _titleController.text = 'My Routine';
      _phases.clear();
    });
  }

  void _saveRoutine() {
    if (!_canSaveRoutine) return;

    final title = _titleController.text.trim().isEmpty
        ? 'My Routine'
        : _titleController.text.trim();

    final task = MainTask(
      title: title,
      phases: List<TaskPhase>.from(_phases),
      currentPhaseIndex: 0,
    );

    context.read<TaskProvider>().setActiveTask(task);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final titleColor = colorScheme.onSurface;
    final mutedColor = colorScheme.onSurfaceVariant;
    final lineColor = colorScheme.outline;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Routine',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor.withValues(alpha: 0.7)),
                ),
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(color: titleColor),
                  cursorColor: titleColor,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Routine title',
                    hintStyle: TextStyle(color: mutedColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Phases',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: titleColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _importFromCSV,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Import CSV'),
                    style: TextButton.styleFrom(foregroundColor: mutedColor),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _showAddPhaseDialog,
                    child: const Text('Add Phase'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _phases.isEmpty
                    ? Center(
                        child: Text(
                          'No phases yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _phases.length,
                        separatorBuilder: (_, _) =>
                            Divider(color: lineColor, height: 1),
                        itemBuilder: (context, index) {
                          final phase = _phases[index];

                          return Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: lineColor.withValues(alpha: 0.6),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        phase.name,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: titleColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatMinutes(phase.duration),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: mutedColor),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: index == 0
                                      ? null
                                      : () => _movePhaseUp(index),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                  ),
                                  color: mutedColor,
                                  tooltip: 'Move up',
                                ),
                                IconButton(
                                  onPressed: index == _phases.length - 1
                                      ? null
                                      : () => _movePhaseDown(index),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  color: mutedColor,
                                  tooltip: 'Move down',
                                ),
                                IconButton(
                                  onPressed: () => _removePhase(index),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: mutedColor,
                                  tooltip: 'Delete phase',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetRoutine,
                    child: const Text('Reset Routine'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _canSaveRoutine ? _saveRoutine : null,
                    child: const Text('Save Routine'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

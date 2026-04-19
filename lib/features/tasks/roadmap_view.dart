import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'task_creator_screen.dart';
import 'task_provider.dart';

class RoadmapView extends StatelessWidget {
  const RoadmapView({super.key, this.embedded = false});

  final bool embedded;

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '${minutes}m';
    }
    return '${hours}h ${minutes}m';
  }

  Future<void> _showTemplateSheet(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final nameController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Templates',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Template name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final templateName = nameController.text.trim();
                        await taskProvider.saveCurrentAsTemplate(templateName);
                        nameController.clear();
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Current'),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Consumer<TaskProvider>(
                        builder: (context, provider, _) {
                          if (provider.savedTemplates.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  'No saved templates yet',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: provider.savedTemplates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final template = provider.savedTemplates[index];
                              final totalMinutes = Duration(
                                seconds: template.originalDurationSeconds,
                              ).inMinutes;

                              return Material(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    await provider.applyTemplate(template);
                                    if (context.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                template.name,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.onSurface,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${template.phases.length} phases • ${totalMinutes}m',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            await provider.deleteTemplate(
                                              index,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          tooltip: 'Delete template',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.activeTask;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;
    final surfaceText = colorScheme.onSurface;
    final mutedText = colorScheme.onSurfaceVariant;
    final accent = colorScheme.secondary;

    final header = Padding(
      padding: embedded
          ? const EdgeInsets.fromLTRB(2, 0, 2, 8)
          : const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: Row(
        children: [
          Text(
            'Current Routine',
            style: theme.textTheme.titleMedium?.copyWith(color: surfaceText),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TaskCreatorScreen(),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Edit routine',
          ),
          IconButton(
            onPressed: () => _showTemplateSheet(context),
            icon: const Icon(Icons.bookmark_added_outlined),
            tooltip: 'Templates',
          ),
        ],
      ),
    );

    if (task.phases.isEmpty) {
      final emptyState = Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No phases yet',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

      if (embedded) {
        return emptyState;
      }

      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: emptyState),
      );
    }

    final phaseList = Column(
      children: [
        header,
        Expanded(
          child: ListView.separated(
            padding: embedded
                ? const EdgeInsets.fromLTRB(2, 0, 2, 2)
                : const EdgeInsets.fromLTRB(24, 0, 24, 28),
            itemBuilder: (context, index) {
              final phase = task.phases[index];
              final isCompleted = index < task.currentPhaseIndex;
              final isActive = index == task.currentPhaseIndex;

              final double baseOpacity = isCompleted
                  ? 0.35
                  : isActive
                  ? 1.0
                  : 0.62;

              final titleColor = isActive
                  ? accent
                  : isCompleted
                  ? mutedText
                  : surfaceText;

              final icon = isCompleted
                  ? Icon(Icons.check_rounded, size: 20, color: mutedText)
                  : isActive
                  ? Icon(
                      Icons.play_circle_fill_rounded,
                      size: 20,
                      color: accent,
                    )
                  : Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: mutedText.withValues(alpha: 0.9),
                    );

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                opacity: baseOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outline.withValues(
                        alpha: isActive ? 0.9 : 0.4,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: icon,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              phase.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: titleColor,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDuration(phase.duration),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isActive ? accent : mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemCount: task.phases.length,
          ),
        ),
      ],
    );

    if (embedded) {
      return phaseList;
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: phaseList),
    );
  }
}

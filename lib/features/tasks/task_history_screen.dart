import 'package:flutter/material.dart';

import 'task_creator_screen.dart';

class TaskHistoryScreen extends StatelessWidget {
  const TaskHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final outline = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: outline.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tasks',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No history yet. Edit your routine to begin your roadmap.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TaskCreatorScreen(),
                    ),
                  );
                },
                child: const Text('Edit Routine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

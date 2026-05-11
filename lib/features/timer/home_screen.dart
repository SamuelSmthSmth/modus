import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/settings_provider.dart';
import '../../core/settings_screen.dart';
import '../online/online_screen.dart';
import '../tasks/flow_editor_view.dart';
import '../tasks/roadmap_view.dart';
import '../tasks/task_provider.dart';
import '../../models/app_mode.dart';
import 'timer_logic.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _selectedTabIndex = 1;
  AppMode _mode = AppMode.timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.05,
      value: 1,
      duration: const Duration(seconds: 4),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TimerProvider>().setMode(_mode);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  void _syncPulse(bool isRunning) {
    if (isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
    if (!isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1;
    }
  }

  Future<void> _onPlayPause(TimerProvider provider) async {
    final taskProvider = context.read<TaskProvider>();

    if (provider.isRunning) {
      await provider.pauseTimer();
      return;
    }

    if (_mode == AppMode.flow) {
      await provider.startOrResumeFlow();
      return;
    }

    if (provider.remaining > Duration.zero) {
      await provider.startTimer(provider.remaining);
      return;
    }

    Duration startFrom;

    if (_mode == AppMode.pomodoro) {
      final activeTask = taskProvider.activeTask;
      final phaseIndex = activeTask.currentPhaseIndex;
      final phases = activeTask.phases;
      if (phaseIndex >= 0 && phaseIndex < phases.length) {
        startFrom = phases[phaseIndex].duration;
      } else {
        startFrom = provider.customDurationForMode(_mode);
      }
    } else {
      startFrom = provider.remaining > Duration.zero
          ? provider.remaining
          : provider.customDurationForMode(_mode);
    }

    await provider.startTimer(startFrom);
  }

  Future<void> _onStop(TimerProvider provider) async {
    await provider.stopTimer();
  }

  Future<void> _openDurationPicker({
    required BuildContext context,
    required TimerProvider provider,
  }) async {
    if (_mode == AppMode.pomodoro) {
      return;
    }

    Duration selected = provider.customDurationForMode(_mode);

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      Text(
                        'Set Duration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          provider.setCustomDuration(_mode, selected);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    initialTimerDuration: selected,
                    onTimerDurationChanged: (value) {
                      if (value <= Duration.zero) return;
                      selected = value;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final backgroundColor = theme.scaffoldBackgroundColor;
    final foregroundColor = colorScheme.onSurface;
    final quietColor = colorScheme.onSurfaceVariant;
    final desktopBackground = colorScheme.surface;

    final tabs = [
      const OnlineScreen(embedded: true),
      _buildTimerTab(
        context: context,
        theme: theme,
        foregroundColor: foregroundColor,
        quietColor: quietColor,
        zenAnimationEnabled: settings.zenAnimationEnabled,
        isDesktop: false,
      ),
      const RoadmapView(embedded: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: isDesktop ? desktopBackground : backgroundColor,
          body: isDesktop
              ? Theme(
                  data: theme.copyWith(
                    scaffoldBackgroundColor: desktopBackground,
                  ),
                  child: ColoredBox(
                    color: desktopBackground,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTimerTab(
                            context: context,
                            theme: theme,
                            foregroundColor: foregroundColor,
                            quietColor: quietColor,
                            zenAnimationEnabled: settings.zenAnimationEnabled,
                            isDesktop: true,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          indent: 24,
                          endIndent: 24,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.22,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                24,
                                16,
                              ),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const OnlineScreen(embedded: true),
                                      const SizedBox(height: 16),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.28),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 360,
                                        child: const RoadmapView(
                                          embedded: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : IndexedStack(index: _selectedTabIndex, children: tabs),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  currentIndex: _selectedTabIndex,
                  onTap: (value) {
                    setState(() {
                      _selectedTabIndex = value;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  backgroundColor: backgroundColor,
                  elevation: 0,
                  selectedItemColor: foregroundColor,
                  unselectedItemColor: quietColor,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.public_outlined),
                      activeIcon: Icon(Icons.public),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.timer_outlined),
                      activeIcon: Icon(Icons.timer),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.list_alt_outlined),
                      activeIcon: Icon(Icons.list_alt),
                      label: '',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTimerTab({
    required BuildContext context,
    required ThemeData theme,
    required Color foregroundColor,
    required Color quietColor,
    required bool zenAnimationEnabled,
    required bool isDesktop,
  }) {
    final provider = context.watch<TimerProvider>();
    final remaining = provider.remaining;
    final isRunning = provider.isRunning;

    _syncPulse(isRunning);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.settings_outlined, color: quietColor),
                  tooltip: 'Settings',
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: SegmentedButton<AppMode>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  side: WidgetStatePropertyAll(
                    BorderSide(color: quietColor.withValues(alpha: 0.3)),
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return foregroundColor;
                    }
                    return quietColor;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return foregroundColor.withValues(alpha: 0.08);
                    }
                    return Colors.transparent;
                  }),
                ),
                segments: const [
                  ButtonSegment<AppMode>(
                    value: AppMode.timer,
                    label: Text('Timer'),
                  ),
                  ButtonSegment<AppMode>(
                    value: AppMode.pomodoro,
                    label: Text('Pomodoro'),
                  ),
                  ButtonSegment<AppMode>(
                    value: AppMode.flow,
                    label: Text('Flow'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selected) {
                  final nextMode = selected.first;
                  setState(() {
                    _mode = nextMode;
                  });
                  context.read<TimerProvider>().setMode(nextMode);
                },
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _mode == AppMode.flow
                      ? const FlowEditorView(key: ValueKey('flow-editor'))
                      : GestureDetector(
                          key: const ValueKey('time-text'),
                          onTap: _mode == AppMode.timer
                              ? () => _openDurationPicker(
                                  context: context,
                                  provider: provider,
                                )
                              : null,
                          child: Text(
                            _formatDuration(remaining),
                            style:
                                theme.textTheme.displayLarge?.copyWith(
                                  fontSize: 96,
                                  letterSpacing: -2,
                                  fontWeight: FontWeight.w300,
                                  color: foregroundColor,
                                ) ??
                                TextStyle(
                                  fontSize: 96,
                                  letterSpacing: -2,
                                  fontWeight: FontWeight.w300,
                                  color: foregroundColor,
                                ),
                          ),
                        ),
                ),
              ),
            ),
            if (_mode == AppMode.pomodoro && !isDesktop) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: RoadmapView(embedded: true),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _onPlayPause(provider),
                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(isRunning ? 'Pause' : 'Play'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: quietColor.withValues(alpha: 0.45)),
                    foregroundColor: foregroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _onStop(provider),
                  style: TextButton.styleFrom(foregroundColor: quietColor),
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _RoutineTemplateBar(mode: _mode),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _promptSaveNewTemplate(BuildContext context, AppMode mode) async {
  final defaultName =
      mode == AppMode.flow ? 'My Flow Template' : 'My Pomodoro Template';
  final controller = TextEditingController(text: defaultName);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Save as new template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Template name'),
          autofocus: true,
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (!context.mounted || name == null) {
    return;
  }

  final taskProvider = context.read<TaskProvider>();
  if (mode == AppMode.flow) {
    await taskProvider.saveActiveFlowAsNewTemplate(name);
  } else {
    await taskProvider.saveCurrentAsTemplate(name);
  }
}

class _RoutineTemplateBar extends StatelessWidget {
  const _RoutineTemplateBar({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == AppMode.timer) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final tasks = context.watch<TaskProvider>();

    if (mode == AppMode.flow) {
      if (tasks.flowTemplates.isEmpty) {
        return Text(
          'No saved flows yet.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
          textAlign: TextAlign.end,
        );
      }

      var flowId = tasks.activeFlow?.id;
      if (flowId == null ||
          !tasks.flowTemplates.any((template) => template.id == flowId)) {
        flowId = tasks.flowTemplates.first.id;
      }

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current routine',
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: flowId,
                    hint: const Text('Select flow'),
                    items: tasks.flowTemplates
                        .map(
                          (template) => DropdownMenuItem<String>(
                            value: template.id,
                            child: Text(
                              template.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        context.read<TaskProvider>().setActiveFlowById(id);
                      }
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: tasks.activeFlow == null
                      ? null
                      : () => _promptSaveNewTemplate(context, AppMode.flow),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Save as New'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (tasks.savedTemplates.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Current routine',
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 6),
            Text(
              'No saved Pomodoro templates.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.end,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _promptSaveNewTemplate(context, AppMode.pomodoro),
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Save as New'),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Current routine',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: null,
                  hint: const Text('Load template'),
                  items: [
                    for (var i = 0; i < tasks.savedTemplates.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          tasks.savedTemplates[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (index) {
                    if (index == null) return;
                    context.read<TaskProvider>().applyTemplate(
                      tasks.savedTemplates[index],
                    );
                  },
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    _promptSaveNewTemplate(context, AppMode.pomodoro),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Save as New'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

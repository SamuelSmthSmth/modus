import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/workflow_node.dart';
import 'task_provider.dart';

enum _NewNodeType { start, work, decision, jump, end, action }

class FlowEditorView extends StatelessWidget {
  const FlowEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final activeFlow = provider.activeFlow;

    if (activeFlow == null) {
      return Center(
        child: ElevatedButton(
          onPressed: () => provider.createNewFlow('My First Flow'),
          child: const Text('Create New Flow'),
        ),
      );
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final baselineConnector = theme.colorScheme.outline.withValues(alpha: 0.55);
    final activeNodeId = provider.activeNodeId;

    final jumpTargets = _collectJumpTargets(activeFlow.startingNodes);
    final nodes = _buildHorizontalSequence(
      context,
      activeFlow.startingNodes,
      activeFlow.startingNodes,
      jumpTargets,
      accentColor: accent,
      baselineConnector: baselineConnector,
      activeNodeId: activeNodeId,
    );

    final screenSize = MediaQuery.sizeOf(context);

    return Container(
      color: Colors.transparent,
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 4.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: screenSize.width,
            minHeight: screenSize.height,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 40, 56),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: nodes,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddNodeSheet(
    BuildContext context,
    List<WorkflowNode> targetList,
    List<_JumpTarget> jumpTargets,
  ) async {
    final provider = context.read<TaskProvider>();
    final selectedType = await showModalBottomSheet<_NewNodeType>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Add Start Block'),
                onTap: () => Navigator.of(sheetContext).pop(_NewNodeType.start),
              ),
              ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: const Text('Add Work Block'),
                onTap: () => Navigator.of(sheetContext).pop(_NewNodeType.work),
              ),
              ListTile(
                leading: const Icon(Icons.call_split_outlined),
                title: const Text('Add Decision'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_NewNodeType.decision),
              ),
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Add End Block'),
                onTap: () => Navigator.of(sheetContext).pop(_NewNodeType.end),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Loop/Jump to Previous'),
                onTap: () => Navigator.of(sheetContext).pop(_NewNodeType.jump),
              ),
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: const Text('Add Action'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_NewNodeType.action),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || selectedType == null) {
      return;
    }

    switch (selectedType) {
      case _NewNodeType.start:
        await _showStartDialog(context, provider, targetList);
      case _NewNodeType.work:
        await _showWorkDialog(context, provider, targetList);
      case _NewNodeType.decision:
        await _showDecisionDialog(context, provider, targetList);
      case _NewNodeType.jump:
        await _showJumpDialog(context, provider, targetList, jumpTargets);
      case _NewNodeType.end:
        await _showEndDialog(context, provider, targetList);
      case _NewNodeType.action:
        await _showActionDialog(context, provider, targetList);
    }
  }

  List<Widget> _buildHorizontalSequence(
    BuildContext context,
    List<WorkflowNode> nodes,
    List<WorkflowNode> targetList,
    List<_JumpTarget> jumpTargets, {
    required Color accentColor,
    required Color baselineConnector,
    required String? activeNodeId,
  }) {
    final widgets = <Widget>[];
    if (nodes.isEmpty) {
      widgets.add(
        _buildAddButton(
          context,
          targetList,
          jumpTargets,
          accentColor: accentColor,
        ),
      );
      return widgets;
    }

    WorkflowNode? renderedLastNode;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      renderedLastNode = node;
      widgets.add(
        _buildNode(
          context,
          node,
          targetList,
          jumpTargets,
          accentColor: accentColor,
          baselineConnector: baselineConnector,
          activeNodeId: activeNodeId,
        ),
      );

      if (_isTerminal(node)) {
        break;
      }

      // Decision: branches own the + buttons; no main-row connector/+ after the block.
      if (node is DecisionNode) {
        continue;
      }

      if (i < nodes.length - 1) {
        final emphasize =
            _listSubtreeContainsActive([nodes[i + 1]], activeNodeId);
        widgets.add(
          _buildConnector(
            emphasize: emphasize,
            accentColor: accentColor,
            baselineConnector: baselineConnector,
          ),
        );
        widgets.add(
          _buildAddButton(
            context,
            targetList,
            jumpTargets,
            accentColor: accentColor,
          ),
        );
        widgets.add(
          _buildConnector(
            emphasize: emphasize,
            accentColor: accentColor,
            baselineConnector: baselineConnector,
          ),
        );
      }
    }

    if (renderedLastNode != null &&
        !_isTerminal(renderedLastNode) &&
        renderedLastNode is! DecisionNode) {
      final tailActive = _listSubtreeContainsActive(nodes, activeNodeId);
      widgets.add(
        _buildConnector(
          emphasize: tailActive,
          accentColor: accentColor,
          baselineConnector: baselineConnector,
        ),
      );
      widgets.add(
        _buildAddButton(
          context,
          targetList,
          jumpTargets,
          accentColor: accentColor,
        ),
      );
    }

    return widgets;
  }

  Widget _buildNode(
    BuildContext context,
    WorkflowNode node,
    List<WorkflowNode> targetList,
    List<_JumpTarget> jumpTargets, {
    required Color accentColor,
    required Color baselineConnector,
    required String? activeNodeId,
  }) {
    final isActive = node.id == activeNodeId;
    final theme = Theme.of(context);
    final surfaceColor = theme.cardColor;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final onSurfaceVariantColor = theme.colorScheme.onSurfaceVariant;
    final subtleBorder = accentColor.withValues(alpha: 0.3);

    if (node is StartNode) {
      return _wrapEditable(
        onTap: () => _showStartEditDialog(context, targetList, node),
        child: _decorateNodeActiveState(
          _buildPillNode(
            icon: Icons.play_arrow_rounded,
            label: node.title,
            background: surfaceColor,
            border: subtleBorder,
            foregroundColor: onSurfaceColor,
            iconColor: onSurfaceVariantColor,
          ),
          isActive,
          accentColor: accentColor,
        ),
      );
    }

    if (node is WorkNode) {
      return _wrapEditable(
        onTap: () => _showWorkEditDialog(context, targetList, node),
        child: _decorateNodeActiveState(
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: subtleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: onSurfaceVariantColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        node.title,
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${node.durationMinutes}:00m',
                  style: TextStyle(
                    color: onSurfaceVariantColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          isActive,
          accentColor: accentColor,
        ),
      );
    }

    if (node is DecisionNode) {
      final pathAActive = _listSubtreeContainsActive(node.pathA, activeNodeId);
      final pathBActive = _listSubtreeContainsActive(node.pathB, activeNodeId);
      final spineActive = isActive || pathAActive || pathBActive;
      final spineColor =
          spineActive ? accentColor.withValues(alpha: 0.9) : baselineConnector;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _wrapEditable(
                  onTap: () =>
                      _showDecisionEditDialog(context, targetList, node),
                  child: _decorateNodeActiveState(
                      _buildDecisionDiamond(
                        node,
                        background: surfaceColor,
                        borderColor: subtleBorder,
                        foregroundColor: onSurfaceColor,
                        iconColor: onSurfaceVariantColor,
                      ),
                    isActive,
                    accentColor: accentColor,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: spineColor, width: 2),
                  ),
                ),
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBranchRow(
                      context: context,
                      label: 'A: ${node.labelA}',
                      labelColor: pathAActive
                          ? accentColor
                          : const Color(0xFFA9CF52),
                      nodes: node.pathA,
                      jumpTargets: jumpTargets,
                      accentColor: accentColor,
                      baselineConnector: baselineConnector,
                      activeNodeId: activeNodeId,
                    ),
                    const SizedBox(height: 250),
                    _buildBranchRow(
                      context: context,
                      label: 'B: ${node.labelB}',
                      labelColor: pathBActive
                          ? accentColor
                          : const Color(0xFFFF7D87),
                      nodes: node.pathB,
                      jumpTargets: jumpTargets,
                      accentColor: accentColor,
                      baselineConnector: baselineConnector,
                      activeNodeId: activeNodeId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (node is EndNode) {
      return _wrapEditable(
        onTap: () => _showEndEditDialog(context, targetList, node),
        child: _decorateNodeActiveState(
          _buildPillNode(
            icon: Icons.check_rounded,
            label: node.title,
            background: surfaceColor,
            border: subtleBorder,
            foregroundColor: onSurfaceColor,
            iconColor: onSurfaceVariantColor,
          ),
          isActive,
          accentColor: accentColor,
        ),
      );
    }

    if (node is JumpNode) {
      final targetName = _resolveTargetName(node.targetNodeId, jumpTargets);
      return _wrapEditable(
        onTap: () =>
            _showJumpEditDialog(context, targetList, node, jumpTargets),
        child: _decorateNodeActiveState(
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: subtleBorder),
            ),
            child: Text(
              '🔁 Loops to: $targetName',
              style: TextStyle(color: onSurfaceColor, fontSize: 12),
            ),
          ),
          isActive,
          accentColor: accentColor,
        ),
      );
    }

    if (node is ActionNode) {
      return _wrapEditable(
        onTap: () => _showActionEditDialog(context, targetList, node),
        child: _decorateNodeActiveState(
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: subtleBorder),
            ),
            child: Text(
              node.actionType,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurfaceColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          isActive,
          accentColor: accentColor,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBranchRow({
    required BuildContext context,
    required String label,
    required Color labelColor,
    required List<WorkflowNode> nodes,
    required List<_JumpTarget> jumpTargets,
    required Color accentColor,
    required Color baselineConnector,
    required String? activeNodeId,
  }) {
    final branchHasActive = _listSubtreeContainsActive(nodes, activeNodeId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 2,
          color: branchHasActive ? accentColor.withValues(alpha: 0.9) : baselineConnector,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: labelColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        ..._buildHorizontalSequence(
          context,
          nodes,
          nodes,
          jumpTargets,
          accentColor: accentColor,
          baselineConnector: baselineConnector,
          activeNodeId: activeNodeId,
        ),
      ],
    );
  }

  bool _isTerminal(WorkflowNode node) => node is EndNode || node is JumpNode;

  bool _listSubtreeContainsActive(List<WorkflowNode> roots, String? activeId) {
    if (activeId == null) return false;
    for (final n in roots) {
      if (n.id == activeId) return true;
      if (n is DecisionNode) {
        if (_listSubtreeContainsActive(n.pathA, activeId) ||
            _listSubtreeContainsActive(n.pathB, activeId)) {
          return true;
        }
      } else if (n is LoopNode) {
        if (_listSubtreeContainsActive(n.tasks, activeId)) return true;
      }
    }
    return false;
  }

  List<_JumpTarget> _collectJumpTargets(List<WorkflowNode> roots) {
    final targets = <_JumpTarget>[];

    void visit(List<WorkflowNode> nodes) {
      for (final node in nodes) {
        if (node is WorkNode) {
          targets.add(_JumpTarget(id: node.id, title: node.title));
        } else if (node is DecisionNode) {
          targets.add(_JumpTarget(id: node.id, title: node.question));
          visit(node.pathA);
          visit(node.pathB);
        } else if (node is LoopNode) {
          visit(node.tasks);
        }
      }
    }

    visit(roots);
    return targets;
  }

  String _resolveTargetName(String targetId, List<_JumpTarget> jumpTargets) {
    for (final target in jumpTargets) {
      if (target.id == targetId) {
        return target.title;
      }
    }
    return targetId;
  }

  Widget _buildDecisionDiamond(
    DecisionNode node, {
    required Color background,
    required Color borderColor,
    required Color foregroundColor,
    required Color iconColor,
  }) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Transform.rotate(
          angle: -0.785398,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 15,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      node.question,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillNode({
    required IconData icon,
    required String label,
    required Color background,
    required Color border,
    required Color foregroundColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector({
    required bool emphasize,
    required Color accentColor,
    required Color baselineConnector,
  }) {
    return Container(
      width: 36,
      height: 2,
      color: emphasize
          ? accentColor.withValues(alpha: 0.9)
          : baselineConnector,
    );
  }

  Widget _decorateNodeActiveState(
    Widget child,
    bool isActive, {
    required Color accentColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
        border: Border.all(
          color: isActive ? accentColor : Colors.transparent,
          width: isActive ? 2 : 0,
        ),
      ),
      child: child,
    );
  }

  Widget _wrapEditable({required VoidCallback onTap, required Widget child}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: child,
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    List<WorkflowNode> targetList,
    List<_JumpTarget> jumpTargets, {
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: () => _showAddNodeSheet(context, targetList, jumpTargets),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(24, 24),
          maximumSize: const Size(24, 24),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: BorderSide(color: accentColor.withValues(alpha: 0.65)),
          foregroundColor: accentColor,
        ),
        child: const Icon(Icons.add, size: 12),
      ),
    );
  }

  Future<void> _showStartDialog(
    BuildContext context,
    TaskProvider provider,
    List<WorkflowNode> targetList,
  ) async {
    final titleController = TextEditingController(text: 'START');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Start Block'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Start Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.addNodeToFlow(
                targetList,
                StartNode(
                  id: const Uuid().v4(),
                  type: 'start',
                  title: titleController.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
  }

  Future<void> _showWorkDialog(
    BuildContext context,
    TaskProvider provider,
    List<WorkflowNode> targetList,
  ) async {
    final nameController = TextEditingController();
    var selectedDuration = const Duration(minutes: 25);
    var autoStart = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Work Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Block Name'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Duration'),
                subtitle: Text(_formatHms(selectedDuration)),
                trailing: const Icon(Icons.timer_outlined),
                onTap: () async {
                  final picked = await _showDurationPickerHms(
                    context,
                    selectedDuration,
                  );
                  if (picked != null) {
                    setState(() => selectedDuration = picked);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-start next phase'),
                value: autoStart,
                onChanged: (value) => setState(() => autoStart = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                provider.addNodeToFlow(
                  targetList,
                  WorkNode(
                    id: const Uuid().v4(),
                    type: 'work',
                    title: nameController.text.trim(),
                    durationSeconds: selectedDuration.inSeconds,
                    autoStart: autoStart,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _showDecisionDialog(
    BuildContext context,
    TaskProvider provider,
    List<WorkflowNode> targetList,
  ) async {
    final questionController = TextEditingController();
    final topController = TextEditingController(text: 'Yes');
    final bottomController = TextEditingController(text: 'No');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Decision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                labelText: 'Question/Condition',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: topController,
              decoration: const InputDecoration(labelText: 'Top Branch Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bottomController,
              decoration: const InputDecoration(
                labelText: 'Bottom Branch Label',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.addNodeToFlow(
                targetList,
                DecisionNode(
                  id: const Uuid().v4(),
                  type: 'decision',
                  question: questionController.text.trim(),
                  pathA: [],
                  pathB: [],
                  labelA: topController.text.trim(),
                  labelB: bottomController.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    questionController.dispose();
    topController.dispose();
    bottomController.dispose();
  }

  Future<void> _showActionDialog(
    BuildContext context,
    TaskProvider provider,
    List<WorkflowNode> targetList,
  ) async {
    final controller = TextEditingController(text: 'playSound');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Action'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Action'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.addNodeToFlow(
                targetList,
                ActionNode(
                  id: const Uuid().v4(),
                  type: 'action',
                  actionType: controller.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showEndDialog(
    BuildContext context,
    TaskProvider provider,
    List<WorkflowNode> targetList,
  ) async {
    final controller = TextEditingController(text: 'END');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create End Block'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'End Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.addNodeToFlow(
                targetList,
                EndNode(
                  id: const Uuid().v4(),
                  type: 'end',
                  title: controller.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showJumpDialog(
    BuildContext context,
    TaskProvider provider,
    List<WorkflowNode> targetList,
    List<_JumpTarget> jumpTargets,
  ) async {
    if (jumpTargets.isEmpty) {
      return;
    }
    var selectedId = jumpTargets.first.id;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Jump Node'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: const InputDecoration(labelText: 'Jump Target'),
            items: jumpTargets
                .map(
                  (target) => DropdownMenuItem<String>(
                    value: target.id,
                    child: Text(target.title),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedId = value);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.addNodeToFlow(
                targetList,
                JumpNode(
                  id: const Uuid().v4(),
                  type: 'jump',
                  targetNodeId: selectedId,
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStartEditDialog(
    BuildContext context,
    List<WorkflowNode> targetList,
    StartNode node,
  ) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController(text: node.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Start Block'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Start Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNodeInFlow(
                targetList,
                node,
                StartNode(
                  id: node.id,
                  type: 'start',
                  title: controller.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showWorkEditDialog(
    BuildContext context,
    List<WorkflowNode> targetList,
    WorkNode node,
  ) async {
    final provider = context.read<TaskProvider>();
    final nameController = TextEditingController(text: node.title);
    var selectedDuration = node.duration;
    var autoStart = node.autoStart;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Work Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Block Name'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Duration'),
                subtitle: Text(_formatHms(selectedDuration)),
                trailing: const Icon(Icons.timer_outlined),
                onTap: () async {
                  final picked = await _showDurationPickerHms(
                    context,
                    selectedDuration,
                  );
                  if (picked != null) {
                    setState(() => selectedDuration = picked);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-start next phase'),
                value: autoStart,
                onChanged: (value) => setState(() => autoStart = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                provider.deleteNode(node.id);
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete Node'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                provider.updateNodeInFlow(
                  targetList,
                  node,
                  WorkNode(
                    id: node.id,
                    type: 'work',
                    title: nameController.text.trim(),
                    durationSeconds: selectedDuration.inSeconds,
                    autoStart: autoStart,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  String _formatHms(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<Duration?> _showDurationPickerHms(
    BuildContext context,
    Duration initial,
  ) async {
    var selected = initial;
    final result = await showModalBottomSheet<Duration>(
      context: context,
      builder: (sheetContext) {
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
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selected),
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    initialTimerDuration: selected,
                    onTimerDurationChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  Future<void> _showDecisionEditDialog(
    BuildContext context,
    List<WorkflowNode> targetList,
    DecisionNode node,
  ) async {
    final provider = context.read<TaskProvider>();
    final questionController = TextEditingController(text: node.question);
    final topController = TextEditingController(text: node.labelA);
    final bottomController = TextEditingController(text: node.labelB);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Decision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                labelText: 'Question/Condition',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: topController,
              decoration: const InputDecoration(labelText: 'Top Branch Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bottomController,
              decoration: const InputDecoration(
                labelText: 'Bottom Branch Label',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.deleteNode(node.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete Node'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNodeInFlow(
                targetList,
                node,
                DecisionNode(
                  id: node.id,
                  type: 'decision',
                  question: questionController.text.trim(),
                  pathA: node.pathA,
                  pathB: node.pathB,
                  labelA: topController.text.trim(),
                  labelB: bottomController.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    questionController.dispose();
    topController.dispose();
    bottomController.dispose();
  }

  Future<void> _showActionEditDialog(
    BuildContext context,
    List<WorkflowNode> targetList,
    ActionNode node,
  ) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController(text: node.actionType);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Action'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Action'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.deleteNode(node.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete Node'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNodeInFlow(
                targetList,
                node,
                ActionNode(
                  id: node.id,
                  type: 'action',
                  actionType: controller.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showEndEditDialog(
    BuildContext context,
    List<WorkflowNode> targetList,
    EndNode node,
  ) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController(text: node.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit End Block'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'End Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNodeInFlow(
                targetList,
                node,
                EndNode(
                  id: node.id,
                  type: 'end',
                  title: controller.text.trim(),
                ),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showJumpEditDialog(
    BuildContext context,
    List<WorkflowNode> targetList,
    JumpNode node,
    List<_JumpTarget> jumpTargets,
  ) async {
    if (jumpTargets.isEmpty) {
      return;
    }
    final provider = context.read<TaskProvider>();
    var selectedId = jumpTargets.any((target) => target.id == node.targetNodeId)
        ? node.targetNodeId
        : jumpTargets.first.id;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Jump Node'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: const InputDecoration(labelText: 'Jump Target'),
            items: jumpTargets
                .map(
                  (target) => DropdownMenuItem<String>(
                    value: target.id,
                    child: Text(target.title),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedId = value);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.updateNodeInFlow(
                targetList,
                node,
                JumpNode(id: node.id, type: 'jump', targetNodeId: selectedId),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _JumpTarget {
  final String id;
  final String title;

  const _JumpTarget({required this.id, required this.title});
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'online_provider.dart';

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  String _formatMmSs(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final secs = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _phaseNameFromStatus(Map<String, dynamic> status) {
    final task = status['task'];
    if (task is! Map<String, dynamic>) {
      return 'No active phase';
    }

    final index = task['currentPhaseIndex'];
    final phases = task['phases'];
    if (index is! int || phases is! List) {
      return 'No active phase';
    }
    if (index < 0 || index >= phases.length) {
      return 'No active phase';
    }

    final phase = phases[index];
    if (phase is! Map<String, dynamic>) {
      return 'No active phase';
    }

    final name = phase['name'];
    if (name is! String || name.trim().isEmpty) {
      return 'No active phase';
    }

    return name;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage(OnlineProvider provider) async {
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      return;
    }

    await provider.sendChatMessage(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final background = theme.scaffoldBackgroundColor;
    final foreground = colorScheme.onSurface;
    final accent = colorScheme.secondary;
    final muted = colorScheme.onSurfaceVariant;
    final remote = provider.lastRemoteStatus;
    final hasLiveData = provider.isConnected && remote != null;
    final chatMessages = provider.chatMessages;

    final timerMap = remote?['timer'];
    final remainingSeconds = timerMap is Map<String, dynamic>
        ? (timerMap['remainingSeconds'] is int
              ? timerMap['remainingSeconds'] as int
              : 0)
        : 0;
    final isRunning = timerMap is Map<String, dynamic>
        ? (timerMap['isRunning'] == true)
        : false;

    final taskMap = remote?['task'];
    final taskTitle = taskMap is Map<String, dynamic>
        ? (taskMap['title'] as String? ?? 'No active task')
        : 'No active task';
    final currentPhaseName = remote == null
        ? 'No active phase'
        : _phaseNameFromStatus(remote);

    final sectionDecoration = BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
    );

    final hostPeerCount = provider.connectedPeersCount;
    final chatHeight = widget.embedded ? 300.0 : 250.0;
    final chatPanel = Container(
      decoration: sectionDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chat',
            style: theme.textTheme.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: chatMessages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = chatMessages[index];
                      final sender = message['sender'] ?? 'Peer';
                      final text = message['text'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '$sender: $text',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChatMessage(provider),
                  style: TextStyle(color: foreground),
                  decoration: const InputDecoration(
                    hintText: 'Send a message...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _sendChatMessage(provider),
                icon: const Icon(Icons.send),
                color: accent,
              ),
            ],
          ),
        ],
      ),
    );

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Modus Connect',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: sectionDecoration,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My LAN IP',
                style: theme.textTheme.titleMedium?.copyWith(color: foreground),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      provider.hostIpAddress,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: provider.isHosting
                        ? provider.stopHosting
                        : provider.startHosting,
                    child: Text(provider.isHosting ? 'Stop Host' : 'Host'),
                  ),
                ],
              ),
              if (provider.isHosting) ...[
                const SizedBox(height: 10),
                Text(
                  'Peers in Room: $hostPeerCount',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: hostPeerCount > 0 ? provider.sendNudge : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Nudge All'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        Container(
          decoration: sectionDecoration,
          padding: const EdgeInsets.all(14),
          child: hasLiveData
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Peer Data',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatMmSs(remainingSeconds),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isRunning ? 'Running' : 'Paused',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isRunning ? accent : muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      taskTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentPhaseName,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: provider.sendNudge,
                      icon: const Icon(Icons.waving_hand_outlined),
                      label: const Text('Nudge Host'),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: provider.disconnectSession,
                      child: const Text('Disconnect'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Session',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: foreground),
                      decoration: const InputDecoration(
                        hintText: 'Enter Host IP Address (e.g., 192.168.1.x)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            provider.joinSession(_ipController.text);
                          },
                          child: const Text('Connect'),
                        ),
                        const SizedBox(width: 8),
                        if (provider.connectedIpAddress != null)
                          TextButton(
                            onPressed: provider.disconnectSession,
                            child: const Text('Disconnect'),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        if (provider.isConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Connected to ${provider.friendName ?? 'Friend'}',
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: chatHeight),
          child: chatPanel,
        ),
      ],
    );

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: widget.embedded
            ? mainContent
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    children: [mainContent, const SizedBox(height: 20)],
                  ),
                ),
              ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: background, child: content);
    }

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: content,
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';

class WhatsAppMessagesPanel extends StatefulWidget {
  const WhatsAppMessagesPanel({super.key});

  @override
  State<WhatsAppMessagesPanel> createState() => WhatsAppMessagesPanelState();
}

class WhatsAppMessagesPanelState extends State<WhatsAppMessagesPanel> {
  final AdminService _service = AdminService();

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _composerCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  Timer? _listPollTimer;
  Timer? _threadPollTimer;

  bool _loadingConversations = false;
  bool _loadingMessages = false;
  bool _sending = false;

  String? _conversationsError;
  String? _messagesError;

  List<AdminWaConversation> _conversations = [];
  List<AdminWaMessage> _messages = [];

  int? _selectedConversationId;
  bool _mobileThreadOpen = false;

  AdminWaConversation? get _selectedConversation {
    final id = _selectedConversationId;
    if (id == null) return null;

    for (final row in _conversations) {
      if (row.id == id) return row;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    refreshAll();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    _searchCtrl.dispose();
    _composerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> refreshAll() async {
    await _loadConversations(silent: false);
    if (_selectedConversationId != null) {
      await _loadMessages(silent: false);
    }
  }

  void _startPolling() {
    _listPollTimer?.cancel();
    _threadPollTimer?.cancel();

    _listPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadConversations(silent: true);
    });

    _threadPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_selectedConversationId != null) {
        _loadMessages(silent: true);
      }
    });
  }

  void _stopPolling() {
    _listPollTimer?.cancel();
    _threadPollTimer?.cancel();
    _listPollTimer = null;
    _threadPollTimer = null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadConversations({required bool silent}) async {
    if (_loadingConversations) return;

    setState(() {
      _loadingConversations = true;
      if (!silent) _conversationsError = null;
    });

    try {
      final rows = await _service.fetchWaConversations(
        query: _searchCtrl.text.trim(),
        limit: 300,
      );

      final previousId = _selectedConversationId;
      int? nextId = previousId;

      if (rows.isEmpty) {
        nextId = null;
      } else if (nextId == null || !rows.any((c) => c.id == nextId)) {
        nextId = rows.first.id;
      }

      final shouldReloadMessages =
          nextId != null &&
          (nextId != previousId ||
              _messages.isEmpty ||
              _selectedConversation == null);

      if (!mounted) return;
      setState(() {
        _conversations = rows;
        _selectedConversationId = nextId;
        _conversationsError = null;
        if (nextId == null) {
          _messages = [];
          _messagesError = null;
        }
      });

      if (shouldReloadMessages) {
        await _loadMessages(silent: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _conversationsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _loadMessages({required bool silent}) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null || _loadingMessages) return;

    setState(() {
      _loadingMessages = true;
      if (!silent) _messagesError = null;
    });

    try {
      final beforeLastId = _messages.isEmpty ? null : _messages.last.id;
      final rows = await _service.fetchWaConversationMessages(
        conversationId,
        limit: 600,
      );

      if (!mounted) return;
      setState(() {
        _messages = rows;
        _messagesError = null;
      });

      final afterLastId = rows.isEmpty ? null : rows.last.id;
      final shouldScroll = beforeLastId == null || beforeLastId != afterLastId;
      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messagesError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;

    final text = _composerCtrl.text.trim();
    if (text.isEmpty) {
      _toast('Type a message first.');
      return;
    }

    final conversation = _selectedConversation;
    if (conversation == null) {
      _toast('Select a conversation first.');
      return;
    }

    setState(() => _sending = true);
    try {
      await _service.sendWaMessage(conversationId: conversation.id, body: text);
      _composerCtrl.clear();
      await _loadMessages(silent: true);
      await _loadConversations(silent: true);
      _scrollToBottom();
    } catch (e) {
      _toast('Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return dt.toLocal().toString().split('.').first;
  }

  Widget _buildWindowStatusBadge(bool within24HourWindow) {
    final label = within24HourWindow ? '24h open' : 'Template only';
    final bg = within24HourWindow
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.orange.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  void _selectConversation(AdminWaConversation conversation, bool mobileMode) {
    setState(() {
      _selectedConversationId = conversation.id;
      if (mobileMode) _mobileThreadOpen = true;
    });
    _loadMessages(silent: false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 980;

            if (isDesktop) {
              return Row(
                children: [
                  SizedBox(
                    width: 380,
                    child: _buildConversationsPane(mobileMode: false),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildThreadPane(showBackButton: false)),
                ],
              );
            }

            if (_mobileThreadOpen && _selectedConversation != null) {
              return _buildThreadPane(showBackButton: true);
            }

            return _buildConversationsPane(mobileMode: true);
          },
        ),
      ),
    );
  }

  Widget _buildConversationsPane({required bool mobileMode}) {
    final query = _searchCtrl.text.trim();

    return Column(
      children: [
        ListTile(
          title: const Text('WhatsApp Inbox'),
          subtitle: Text('${_conversations.length} conversation(s)'),
          trailing: IconButton(
            tooltip: 'Refresh conversations',
            onPressed: _loadingConversations
                ? null
                : () => _loadConversations(silent: false),
            icon: const Icon(Icons.refresh),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'Search by number or preview',
              border: const OutlineInputBorder(),
              suffixIcon: query.isEmpty
                  ? const Icon(Icons.search)
                  : IconButton(
                      onPressed: () async {
                        _searchCtrl.clear();
                        await _loadConversations(silent: false);
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onSubmitted: (_) => _loadConversations(silent: false),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingConversations && _conversations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _conversationsError != null && _conversations.isEmpty
              ? Center(child: Text('Error: $_conversationsError'))
              : _conversations.isEmpty
              ? const Center(child: Text('No WhatsApp conversations yet.'))
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final row = _conversations[i];
                    final selected = row.id == _selectedConversationId;
                    final preview =
                        (row.lastMessagePreview ?? 'No messages yet').trim();

                    return Material(
                      color: selected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectConversation(row, mobileMode),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      row.waUser,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 110,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _fmtDate(row.lastMessageAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildWindowStatusBadge(
                                      row.within24HourWindow,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThreadPane({required bool showBackButton}) {
    final conversation = _selectedConversation;
    if (conversation == null) {
      return const Center(child: Text('Select a conversation to view thread.'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    setState(() => _mobileThreadOpen = false);
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.waUser,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _buildWindowStatusBadge(conversation.within24HourWindow),
              IconButton(
                tooltip: 'Refresh thread',
                onPressed: _loadingMessages
                    ? null
                    : () => _loadMessages(silent: false),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingMessages && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _messagesError != null && _messages.isEmpty
              ? Center(child: Text('Error: $_messagesError'))
              : _messages.isEmpty
              ? const Center(
                  child: Text('No messages in this conversation yet.'),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final message = _messages[i];
                    final inbound = message.isInbound;

                    return Align(
                      alignment: inbound
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: inbound
                                ? Colors.white10
                                : Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (message.body ?? '').trim().isEmpty
                                    ? '[${message.type}]'
                                    : message.body!,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${inbound ? 'Inbound' : 'Outbound'} • ${message.type} • ${_fmtDate(message.timestamp)}'
                                '${message.deliveryStatus == null ? '' : ' • ${message.deliveryStatus}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composerCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Type a reply',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Sending...' : 'Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

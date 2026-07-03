import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';

/// Messagerie interne locataire ↔ propriétaire (F6), liée aux réservations.
/// Rafraîchissement par polling (WebSocket prévu en prod).
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  List<dynamic> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.get('/conversations');
      setState(() => _conversations = res);
    } on ApiException {
      // réessayable via pull-to-refresh
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Api.currentUser?['id'];
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'La messagerie s’ouvre automatiquement dès qu’une '
                      'réservation est payée.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = _conversations[i];
                      final booking = c['booking'];
                      final iAmOwner = booking['listing']['ownerId'] == myId;
                      final other = iAmOwner
                          ? (booking['renter']['name'] ?? 'Locataire')
                          : 'Propriétaire';
                      final last = (c['messages'] as List).firstOrNull;
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: senegalGreen,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(other),
                        subtitle: Text(
                          last?['body'] ?? booking['listing']['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: c['id'],
                                title: '$other — ${booking['listing']['title']}',
                              ),
                            ))
                            .then((_) => _load()),
                      );
                    },
                  ),
                ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  const ChatScreen({super.key, required this.conversationId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.get('/conversations/${widget.conversationId}/messages');
      if (mounted) setState(() => _messages = res);
    } on ApiException {
      // le polling réessaiera
    }
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    _ctrl.clear();
    try {
      await Api.post(
        '/conversations/${widget.conversationId}/messages',
        body: {'body': body},
      );
      await _load();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Api.currentUser?['id'];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 16))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = m['senderId'] == myId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: mine ? senegalGreen : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      m['body'],
                      style: TextStyle(color: mine ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(hintText: 'Votre message…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: senegalGreen),
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

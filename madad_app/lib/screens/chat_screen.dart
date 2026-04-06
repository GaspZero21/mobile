import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../services/app_token.dart';
import '../widgets/shared_bottom_nav.dart';

// ── Conversations list ─────────────────────────────────────────────────────────
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  List<Map<String, dynamic>> _conversations = [];
  bool    _isLoading = true;
  String? _error;

  Map<String, String> get _headers {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await http.get(
          Uri.parse('$baseUrl/conversations'), headers: _headers);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'];
      List list  = [];
      if (data is List) list = data;
      if (data is Map && data['conversations'] is List) {
        list = data['conversations'];
      }
      setState(() {
        _conversations = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: Column(
        children: [
          Container(
            color: kTeal,
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 20),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Messages',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kWhite)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kTeal))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off, color: kSage, size: 36),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(color: kSage)),
                            TextButton(onPressed: _fetch,
                                child: const Text('Retry',
                                    style: TextStyle(color: kTeal))),
                          ],
                        ))
                    : _conversations.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    color: kSage, size: 48),
                                SizedBox(height: 12),
                                Text('No conversations yet',
                                    style: TextStyle(
                                        color: kSage, fontSize: 14)),
                              ],
                            ))
                        : RefreshIndicator(
                            color: kTeal,
                            onRefresh: _fetch,
                            child: ListView.separated(
                              itemCount: _conversations.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1,
                                      indent: 72,
                                      color: Color(0xFFEEEEEE)),
                              itemBuilder: (_, i) =>
                                  _tile(_conversations[i]),
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 3),
    );
  }

  Widget _tile(Map<String, dynamic> conv) {
    final other      = conv['otherUser'] ?? conv['participant'] ?? {};
    final name       = other['name'] ?? 'Unknown';
    final lastMsg    = conv['lastMessage']?['content'] ?? '';
    final unread     = (conv['unreadCount'] as num?)?.toInt() ?? 0;
    final donationTitle = conv['donation']?['title'] ?? '';

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conv['id'] as String,
            otherName: name,
            donationTitle: donationTitle,
          ),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: kTeal.withOpacity(0.15),
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: kTeal, fontWeight: FontWeight.bold)),
      ),
      title: Text(name,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (donationTitle.isNotEmpty)
            Text('Re: $donationTitle',
                style: const TextStyle(fontSize: 10, color: kTeal)),
          Text(lastMsg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kSage)),
        ],
      ),
      trailing: unread > 0
          ? Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: kTerra, shape: BoxShape.circle),
              child: Center(
                child: Text('$unread',
                    style: const TextStyle(
                        color: kWhite,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            )
          : null,
    );
  }
}

// ── Single conversation ────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherName;
  final String donationTitle;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    required this.donationTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  final _msgController = TextEditingController();
  final _scrollCtrl    = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  Timer? _pollTimer;

  Map<String, String> get _headers {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _fetch();
    // Poll every 5 seconds for new messages
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res  = await http.get(
        Uri.parse('$baseUrl/conversations/${widget.conversationId}/messages'),
        headers: _headers,
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'];
      List list  = [];
      if (data is List) list = data;
      if (data is Map && data['messages'] is List) list = data['messages'];
      if (mounted) {
        setState(() =>
            _messages = List<Map<String, dynamic>>.from(list));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _msgController.clear();
    try {
      await http.post(
        Uri.parse(
            '$baseUrl/conversations/${widget.conversationId}/messages'),
        headers: _headers,
        body: jsonEncode({'content': text}),
      );
      await _fetch();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMe(Map<String, dynamic> msg) {
    // The API should return senderId or a 'isMe' flag
    return msg['isMe'] == true || msg['isMine'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            if (widget.donationTitle.isNotEmpty)
              Text('Re: ${widget.donationTitle}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('No messages yet. Say hello!',
                        style: TextStyle(color: kSage)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          // Input
          Container(
            color: kWhite,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle:
                          const TextStyle(color: kSage, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                        color: kTeal, shape: BoxShape.circle),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: kWhite, strokeWidth: 2))
                        : const Icon(Icons.send,
                            color: kWhite, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> msg) {
    final me      = _isMe(msg);
    final content = msg['content'] ?? '';
    final time    = msg['createdAt'] as String?;

    String timeStr = '';
    if (time != null) {
      final dt = DateTime.tryParse(time);
      if (dt != null) {
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: me ? kTeal : kWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(me ? 16 : 4),
            bottomRight: Radius.circular(me ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(content,
                style: TextStyle(
                    fontSize: 13,
                    color: me ? kWhite : Colors.black87)),
            const SizedBox(height: 4),
            Text(timeStr,
                style: TextStyle(
                    fontSize: 10,
                    color: me
                        ? kWhite.withOpacity(0.7)
                        : kSage)),
          ],
        ),
      ),
    );
  }
}
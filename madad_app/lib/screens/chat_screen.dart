import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/chat_service.dart';
import '../services/app_token.dart';

class ChatScreen extends StatefulWidget {
  final String reservationId;
  final String otherName;
  final String donationTitle;

  const ChatScreen({
    super.key,
    required this.reservationId,
    required this.otherName,
    required this.donationTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollCtrl    = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool   _sending = false;
  bool   _loading = true;
  Timer? _pollTimer;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = AppToken.getUserId(); // ← stored at login, no JWT decode needed
    debugPrint('[Chat] myUserId = $_myUserId');
    _fetch();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    try {
      final data = await ChatService().getChat(widget.reservationId);
      debugPrint('[Chat] raw keys: ${data.keys}');
      final msgs = _extractMessages(data);
      if (msgs.isNotEmpty) {
        debugPrint('[Chat] first msg keys: ${msgs.first.keys}');
        debugPrint('[Chat] first msg: ${msgs.first}');
      }
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading  = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat] fetch error: $e');
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extractMessages(Map<String, dynamic> data) {
    final d = data['data'];
    if (d is Map) {
      if (d['messages'] is List) {
        return List<Map<String, dynamic>>.from(d['messages'] as List);
      }
      if (d['data'] is Map && (d['data'] as Map)['messages'] is List) {
        return List<Map<String, dynamic>>.from(
            (d['data'] as Map)['messages'] as List);
      }
    }
    if (data['messages'] is List) {
      return List<Map<String, dynamic>>.from(data['messages'] as List);
    }
    return [];
  }

  void _scrollToBottom() {
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

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    setState(() => _sending = true);
    try {
      await ChatService().sendMessage(widget.reservationId, text);
      await _fetch(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMe(Map<String, dynamic> msg) {
    // Primary: match stored userId against senderId field
    final senderId =
        msg['senderId']?.toString() ??
        msg['sender']?['id']?.toString() ??
        msg['sender']?['_id']?.toString() ??
        msg['userId']?.toString();

    debugPrint('[Chat] senderId=$senderId myUserId=$_myUserId');

    if (_myUserId != null && senderId != null) {
      return senderId == _myUserId;
    }
    // Fallback: API-provided flags
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kTeal))
                : _messages.isEmpty
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
          // Input bar
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
                      hintText: 'Type something…',
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
        final local = dt.toLocal();
        timeStr =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
                color: Colors.black.withValues(alpha: 0.05),
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
                        ? kWhite.withValues(alpha: 0.7)
                        : kSage)),
          ],
        ),
      ),
    );
  }
}
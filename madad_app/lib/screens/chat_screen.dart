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
    _myUserId = AppToken.getUserId();
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
      final msgs = ChatService().extractMessages(data);
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
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMe(Map<String, dynamic> msg) {
    final senderId =
        msg['senderId']?.toString() ??
        msg['sender']?['id']?.toString() ??
        msg['sender']?['_id']?.toString() ??
        msg['userId']?.toString();
    if (_myUserId != null && senderId != null) return senderId == _myUserId;
    return msg['isMe'] == true || msg['isMine'] == true;
  }

  void _onLongPress(Map<String, dynamic> msg) {
    if (_isMe(msg)) return;
    final messageId = msg['id']?.toString() ?? msg['_id']?.toString() ?? '';
    if (messageId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReportSheet(
        onReport: (reason, details) => _doReport(messageId, reason, details),
      ),
    );
  }

  Future<void> _doReport(
      String messageId, String reason, String? details) async {
    try {
      await ChatService().reportMessage(
        reservationId: widget.reservationId,
        messageId: messageId,
        reason: reason,
        details: details,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message reported. Thank you!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      resizeToAvoidBottomInset: true,
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: kWhite,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type something…',
                        hintStyle: const TextStyle(color: kSage, fontSize: 13),
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
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: kTeal, shape: BoxShape.circle),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  color: kWhite, strokeWidth: 2))
                          : const Icon(Icons.send, color: kWhite, size: 20),
                    ),
                  ),
                ],
              ),
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
      child: GestureDetector(
        onLongPress: me ? null : () => _onLongPress(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              if (!me)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(timeStr,
                      style: TextStyle(fontSize: 10, color: kSage)),
                  const SizedBox(width: 6),
                  Icon(Icons.flag_outlined,
                      size: 10,
                      color: kSage.withValues(alpha: 0.5)),
                ])
              else
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 10,
                        color: kWhite.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Report bottom sheet ───────────────────────────────────────────────────────
class _ReportSheet extends StatefulWidget {
  final void Function(String reason, String? details) onReport;
  const _ReportSheet({required this.onReport});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selected;
  final _detailsCtrl = TextEditingController();

  static const _reasons = [
    ('inappropriate', 'Inappropriate content',  Icons.block),
    ('spam',          'Spam',                    Icons.mark_email_unread_outlined),
    ('harassment',    'Harassment or threats',   Icons.warning_amber_outlined),
    ('phone_number',  'Sharing phone number',    Icons.phone_outlined),
    ('other',         'Other',                   Icons.more_horiz),
  ];

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH  = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          keyboardH > 0 ? keyboardH + 12 : bottomSafe + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Report Message',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ]),
            const SizedBox(height: 6),
            const Text('Why are you reporting this message?',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 16),
            ..._reasons.map((r) {
              final (value, label, icon) = r;
              final selected = _selected == value;
              return GestureDetector(
                onTap: () => setState(() => _selected = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE8F5F3)
                        : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? kTeal : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(children: [
                    Icon(icon,
                        size: 18,
                        color: selected ? kTeal : Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected ? kTeal : Colors.black87)),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: kTeal, size: 18),
                  ]),
                ),
              );
            }),
            if (_selected != null) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _detailsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add details (optional)…',
                  hintStyle: const TextStyle(
                      color: Colors.black38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selected != null ? Colors.red : Colors.grey[300],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _selected == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onReport(
                            _selected!, _detailsCtrl.text.trim());
                      },
                icon: const Icon(Icons.flag, color: Colors.white, size: 18),
                label: const Text('Submit Report',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
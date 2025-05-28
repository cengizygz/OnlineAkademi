import 'package:flutter/material.dart';
import 'package:math_app/core/models/chat_message_model.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/chat_service.dart';

class ClassChatScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ClassChatScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassChatScreen> createState() => _ClassChatScreenState();
}

class _ClassChatScreenState extends State<ClassChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String _errorMessage = '';
  List<ChatMessageModel> _messages = [];

  // Servis
  final ChatService _chatService = ChatService();
  
  // WhatsApp renkleri
  static const Color whatsAppGreen = Color(0xFF128C7E);
  static const Color whatsAppLightGreen = Color(0xFFDCF8C6);
  static const Color whatsAppMessageColor = Colors.white;
  static const Color whatsAppChatBackground = Color(0xFFECE5DD);

  @override
  void initState() {
    super.initState();
    // Add listener to message controller to update UI
    _messageController.addListener(_updateSendButton);
  }

  void _updateSendButton() {
    // Force rebuild when text changes to update the send/mic icon
    setState(() {});
  }

  @override
  void dispose() {
    _messageController.removeListener(_updateSendButton);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mesaj gönder
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = '';
    });

    try {
      await _chatService.sendMessage(widget.classId, message);
      _messageController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderilemedi: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: whatsAppGreen,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.className.isNotEmpty ? widget.className[0] : '',
                style: TextStyle(color: whatsAppGreen),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.className),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {}, // Video call functionality
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {}, // Call functionality
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {}, // More options
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: whatsAppChatBackground,
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                stream: _chatService.getClassMessages(widget.classId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && _messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: whatsAppGreen,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Hata: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  _messages = snapshot.data ?? [];

                  if (_messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz mesaj yok',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageItem(message);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {}, // Emoji picker functionality
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () {}, // Attachment functionality
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Mesajınızı yazın...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isSending 
                      ? null 
                      : () {
                          if (_messageController.text.trim().isNotEmpty) {
                            _sendMessage();
                          } else {
                            // Voice message functionality when input is empty
                          }
                        },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: whatsAppGreen,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _messageController.text.trim().isEmpty ? Icons.mic : Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessageModel message) {
    final currentUserId = _chatService.getCurrentUserId();
    final isMe = currentUserId.isNotEmpty && message.senderId == currentUserId;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe && message.isTeacher)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: whatsAppGreen,
                child: const Icon(Icons.school, color: Colors.white, size: 16),
              ),
            ),
          
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe 
                    ? whatsAppLightGreen 
                    : (message.isTeacher 
                        ? Colors.white.withOpacity(0.95)
                        : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: message.isTeacher ? whatsAppGreen : Colors.blue.shade800,
                              fontSize: 13,
                            ),
                          ),
                          if (message.isTeacher)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: whatsAppGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Öğretmen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp.toDate()),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
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

  // Zaman bilgisini biçimlendir
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDay == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
} 
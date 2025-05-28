import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/models/class_chat_model.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/chat_service.dart';

class ClassChatListScreen extends StatefulWidget {
  const ClassChatListScreen({Key? key}) : super(key: key);

  @override
  State<ClassChatListScreen> createState() => _ClassChatListScreenState();
}

class _ClassChatListScreenState extends State<ClassChatListScreen> {
  final ChatService _chatService = ChatService();
  List<ClassChatModel> _classChats = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // WhatsApp renkleri
  static const Color whatsAppGreen = Color(0xFF128C7E);
  static const Color whatsAppLightGreen = Color(0xFFDCF8C6);

  @override
  void initState() {
    super.initState();
    _loadClassChats();
  }

  Future<void> _loadClassChats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final classChats = await _chatService.getAccessibleClassChats();
      
      setState(() {
        _classChats = classChats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sınıf sohbetleri yüklenirken hata: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: whatsAppGreen,
        title: const Text('Sınıf Sohbetleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {}, // Search functionality
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {}, // More options menu
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: whatsAppGreen))
        : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: whatsAppGreen,
                    ),
                    onPressed: _loadClassChats,
                    child: const Text('Yeniden Dene'),
                  ),
                ],
              ),
            )
          : _classChats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Henüz sohbet yok',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: whatsAppGreen,
                      ),
                      onPressed: _loadClassChats,
                      child: const Text('Yenile'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: _classChats.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 0,
                ),
                itemBuilder: (context, index) {
                  final chat = _classChats[index];
                  return _buildChatItem(chat);
                },
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: whatsAppGreen,
        onPressed: () {}, // New chat functionality
        child: const Icon(Icons.message),
      ),
    );
  }

  Widget _buildChatItem(ClassChatModel chat) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context, 
          AppConstants.routeClassChat,
          arguments: {
            'classId': chat.classId,
            'className': chat.className,
          },
        ).then((_) => _loadClassChats()); // Geri dönüldüğünde yenile
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: whatsAppGreen.withOpacity(0.8),
              child: Text(
                chat.className.isNotEmpty ? chat.className[0] : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.className,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _chatService.formatTimestamp(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.unreadCount > 0 ? whatsAppGreen : Colors.grey.shade600,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: chat.lastMessageText.isNotEmpty 
                          ? RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(
                                  color: chat.unreadCount > 0 
                                      ? Colors.black87 
                                      : Colors.black54,
                                  fontWeight: chat.unreadCount > 0 
                                      ? FontWeight.w600 
                                      : FontWeight.normal,
                                ),
                                children: [
                                  if (chat.lastMessageSender.isNotEmpty)
                                    TextSpan(
                                      text: '${chat.lastMessageSender}: ',
                                      style: TextStyle(
                                        fontWeight: chat.unreadCount > 0 
                                            ? FontWeight.bold 
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  TextSpan(text: chat.lastMessageText),
                                ],
                              ),
                            )
                          : const Text(
                              'Henüz mesaj yok',
                              style: TextStyle(
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: whatsAppGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
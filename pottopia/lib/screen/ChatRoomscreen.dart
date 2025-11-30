import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'write_review.dart';
import 'package:ai_profanity_textfield/ai_profanity_textfield.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final bool isGroup;
  final String chatName;
  final String postId;
  final String postTitle;
  final String postOwnerUid;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.isGroup,
    required this.chatName,
    required this.postId,
    required this.postTitle,
    required this.postOwnerUid,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  final geminiService = GeminiService(
    apiKey: 'AIzaSyD6vbwCPma4sqObheDE0_XFV-MAolD6Pms',
  );

  @override
  void initState() {
    super.initState();
    updateLastRead(widget.chatId, currentUser.uid);
  }

  void updateLastRead(String chatId, String uid) {
    FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'lastReadTimestamps.$uid': FieldValue.serverTimestamp(),
    });
  }

  void sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'text': clean,
          'senderId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
          'lastMessage': clean,
          'timestamp': FieldValue.serverTimestamp(),
        });

    updateLastRead(widget.chatId, currentUser.uid);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.chatName,
          style: const TextStyle(
            color: Color(0xFF7F71FC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF7F71FC)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.more_vert, color: Color(0xFF7F71FC)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF7F71FC)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length + 1, // ⬅️ 버튼 포함해서 +1
                  itemBuilder: (context, index) {
                    // ✅ 리뷰 남기기 버튼 (맨 마지막에 삽입)
                    if (index == messages.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WriteReviewScreen(
                                    chatId: widget.chatId,
                                    targetNickname: widget.chatName,
                                    postId: widget.postId,
                                    postTitle: widget.postTitle, // 게시물 제목
                                    postOwnerUid:
                                        widget.postOwnerUid, // 게시물 주인 UID
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                174,
                                174,
                                247,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              '리뷰 남기기',
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 253, 253),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final msg = messages[index].data() as Map<String, dynamic>;
                    final senderId = msg['senderId'];
                    final isMe = senderId == currentUser.uid;
                    final time =
                        (msg['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    final timeFormatted = DateFormat(
                      'a h:mm',
                      'ko',
                    ).format(time);

                    if (isMe) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                margin: const EdgeInsets.only(left: 40),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDFD9FF),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  msg['text'] ?? '',
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  timeFormatted,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(senderId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const SizedBox();
                          }

                          final nickname =
                              snapshot.data!['nickname'] ?? '알 수 없음';

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                          radius: 18,
                                          backgroundImage: AssetImage(
                                            'assets/man.png',
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          nickname,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    margin: const EdgeInsets.only(right: 40),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F2F2),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      msg['text'] ?? '',
                                      style: const TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(
                                      timeFormatted,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(25),
          ),
          child: ProfanityTextFormField(
            controller: _messageController,
            geminiService: geminiService,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '메시지를 입력하세요',
            ),
            onProfanityDetected: (badText) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('비속어가 감지되었습니다: $badText'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            clearOnProfanity: false,
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.send, color: Color(0xFF775DF8)),
        onPressed: () {
          final text = _messageController.text.trim();
          if (text.isEmpty) return;
          sendMessage(text);
          _messageController.clear();
        },
      ),
        ],
      ),
      
    ),
        ],
      )
    );

  }
}

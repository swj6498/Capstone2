import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ChatRoomscreen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatStream = FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: currentUser.uid) // ✅ 내가 포함된 채팅방
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '채팅',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 0.9, color: Color(0x807F71FC)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data!.docs;

                if (chats.isEmpty) {
                  return const Center(child: Text('참여 중인 채팅방이 없습니다.'));
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final isGroup = chat['isGroup'] ?? false;
                    final members = List<String>.from(chat['members'] ?? []);
                    final chatId = chat.id;
                    final lastMessage = chat['lastMessage'] ?? '';
                    final currentUser = FirebaseAuth.instance.currentUser!;
                    final chatMap =
                        chat.data() as Map<String, dynamic>; // 👈 안전하게 맵으로 변환
                    final postId = chatMap['postId'] ?? '';
                    final postTitle = chatMap['postTitle'] ?? '제목 없음';
                    final postOwnerUid = chatMap['postOwnerUid'] ?? '';

                    if (isGroup) {
                      // ✅ 게시물 채팅방인 경우
                      final groupName = chat['chatName'] ?? '이름 없는 그룹';
                      final postTitle =
                          chat['postTitle']; // Firestore에 저장되어 있으면 게시물 제목
                      final displayName =
                          postTitle != null ? '[게시물] $postTitle' : groupName;

                      return buildChatTile(chatId, displayName, lastMessage,
                          isGroup, postId, postTitle, postOwnerUid, context);
                    } else {
                      // ✅ 1:1 채팅방인 경우
                      final otherUid = members.firstWhere(
                          (uid) => uid != currentUser.uid,
                          orElse: () => '');
                      if (otherUid.isEmpty) {
                        return const ListTile(title: Text('상대 정보 없음'));
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUid)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const ListTile(title: Text('로딩 중...'));
                          }

                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final nickname = data['nickname'] ?? '알 수 없음';

                          return buildChatTile(
                              chatId,
                              nickname,
                              lastMessage,
                              isGroup,
                              postId,
                              postTitle,
                              postOwnerUid,
                              context);
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 안 읽은 메시지 수 계산
  Future<int> _getUnreadCount(String chatId, String uid) async {
    final chatDoc =
        await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    final lastReadTimestamps = chatDoc.data()?['lastReadTimestamps'] ?? {};
    final lastRead = (lastReadTimestamps[uid] as Timestamp?) ?? Timestamp(0, 0);

    final unreadMessages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('timestamp', isGreaterThan: lastRead)
        .get();

    return unreadMessages.docs.length;
  }

  /// ✅ 채팅방 타일 생성
  Widget buildChatTile(
    String chatId,
    String chatName,
    String lastMessage,
    bool isGroup,
    String postId,
    String postTitle, // 🔥 추가
    String postOwnerUid, // 🔥 추가
    BuildContext context,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<int>(
      future: _getUnreadCount(chatId, currentUser.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return ListTile(
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: Color.fromARGB(255, 255, 255, 255),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.asset(
                'assets/profile_picture.png',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: Text(
            chatName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          trailing: unreadCount > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF775DF8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(
                  chatId: chatId,
                  chatName: chatName,
                  isGroup: isGroup,
                  postId: postId,
                  postTitle: postTitle,
                  postOwnerUid: postOwnerUid,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

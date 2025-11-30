import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ChatRoomscreen.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('팟 대기/신청',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 0.6, color: Color(0xFF7F71FC)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildTabButton('신청 목록', 0),
                const SizedBox(width: 8),
                _buildTabButton('대기 목록', 1),
                const SizedBox(width: 8),
                _buildTabButton('참여된 팟', 2), // ✅ 추가
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: selectedIndex == 0
                ? _buildRequestList()
                : selectedIndex == 1
                    ? _buildWaitingList()
                    : _buildAcceptedList(), // ✅ 2번 탭용 함수 호출 추가!
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Container(
        width: 80,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7F71FC) : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('postOwnerId', isEqualTo: user.uid)
          //.where('status', whereIn: ['수락함', '거절함'])
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('에러가 발생했습니다: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('신청한 사람이 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final status = data['status'] ?? '대기중';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 247, 247, 247),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['postTitle'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 25,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['requesterName'] ?? '닉네임 없음',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['message'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      status == '대기중'
                          ? Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection('requests')
                                        .doc(request.id)
                                        .update({'status': '수락함'});

                                    final requesterId = data['requesterId'];
                                    final requesterName =
                                        data['requesterName'] ?? '이름 없음';

                                    final currentUser =
                                        FirebaseAuth.instance.currentUser!;
                                    final chatId = [
                                      currentUser.uid,
                                      requesterId
                                    ]..sort();
                                    final chatDocId = chatId.join('_');

                                    final chatRef = FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(chatDocId);
                                    final chatSnap = await chatRef.get();
                                    final postTitle =
                                        data['postTitle'] ?? '제목 없음';
                                    final postOwnerUid = FirebaseAuth.instance
                                        .currentUser!.uid; // 요청 수락 주체가 게시물 주인

                                    if (!chatSnap.exists) {
                                      await chatRef.set({
                                        'members': [
                                          currentUser.uid,
                                          requesterId
                                        ],
                                        'isGroup': false,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                        'lastMessage': '',
                                      });
                                    }
                                    final postId = data['postId']; //추가
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatRoomScreen(
                                          chatId: chatDocId,
                                          isGroup: false,
                                          chatName: requesterName,
                                          postId: postId,
                                          postTitle: postTitle, // ✅ 게시물 제목
                                          postOwnerUid:
                                              postOwnerUid, // ✅ 게시물 주인 UID
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    'assets/check2.png',
                                    width: 28,
                                    height: 28,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    FirebaseFirestore.instance
                                        .collection('requests')
                                        .doc(request.id)
                                        .update({'status': '거절함'});
                                  },
                                  child: Image.asset(
                                    'assets/cancel.png',
                                    width: 28,
                                    height: 28,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              status,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: status == "수락함"
                                    ? Colors.green
                                    : (status == "거절함"
                                        ? Colors.red
                                        : Colors.black),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWaitingList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('requesterId', isEqualTo: user.uid)
          .where('status', isEqualTo: '대기중')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('에러 발생: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('대기중인 신청이 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;

            final postId = data['postId'];
            final imagePath = data['image'] ?? 'assets/none1.jpg';
            final title = data['postTitle'] ?? '';
            final isOnline = data['isOnline'] ?? true;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .get(),
              builder: (context, postSnapshot) {
                if (!postSnapshot.hasData) return const SizedBox.shrink();

                final postData =
                    postSnapshot.data!.data() as Map<String, dynamic>;
                final maxCount = postData['headcount'] ?? 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('requests')
                      .where('postId', isEqualTo: postId)
                      .where('status', isEqualTo: '수락함')
                      .snapshots(),
                  builder: (context, reqSnapshot) {
                    final currentCount = reqSnapshot.data?.docs.length ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5), // 연한 회색 배경
                        borderRadius: BorderRadius.circular(12),
                        // border 제거됨
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              imagePath,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$title ($currentCount/$maxCount)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            isOnline ? '온라인' : '오프라인',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        '신청대기중',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                          fontSize: 14,
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
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('requesterId', isEqualTo: user.uid)
          .where('status', isEqualTo: '수락함')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('참여된 팟이 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final imagePath = data['image'] ?? 'assets/none1.jpg';
            final title = data['postTitle'] ?? '';
            final isOnline = data['isOnline'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5), // 연회색 배경
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? '온라인' : '오프라인',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '참여 확정된 팟입니다',
                          style: TextStyle(
                              fontSize: 15,
                              color: Color.fromARGB(255, 65, 157, 68)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

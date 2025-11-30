import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Post.dart';

class MyPostListScreen extends StatelessWidget {
  const MyPostListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    print('현재 로그인 UID: ${user?.uid}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '내 게시물',
          style: TextStyle(
            color: Color(0xFF7F71FC), // 연보라색
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF7F71FC)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('ownerId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs;

          if (posts.isEmpty) {
            return const Center(child: Text('작성한 게시물이 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data() as Map<String, dynamic>;
              final postId = posts[index].id;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostScreen(
                        postData: {...data, 'postId': postId},
                        postId: postId,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildPostImage(data['imageUrls']),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('requests')
                                        .where('postId', isEqualTo: postId)
                                        .where('status', isEqualTo: '수락함')
                                        .get(),
                                    builder: (context, snapshot) {
                                      final currentCount =
                                          snapshot.data?.docs.length ?? 0;
                                      final maxCount = data['headcount'] ?? 0;

                                      return Text(
                                        '${data['title'] ?? ''} ($currentCount/$maxCount)',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  data['isOnline'] == true
                                      ? '온라인'
                                      : (data['location'] ?? '위치미제공'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
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
            },
          );
        },
      ),
    );
  }

  Widget _buildPostImage(List<dynamic>? imageUrls) {
    if (imageUrls == null ||
        imageUrls.isEmpty ||
        imageUrls[0].toString().startsWith('assets/')) {
      return Image.asset(
        'assets/none1.jpg',
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrls[0],
      width: 80,
      height: 80,
      fit: BoxFit.cover,
    );
  }
}

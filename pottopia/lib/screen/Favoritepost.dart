import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Post.dart';

class FavoritePostScreen extends StatelessWidget {
  const FavoritePostScreen({super.key});

  Widget _buildPostImage(List<dynamic>? imageUrls) {
    if (imageUrls == null || imageUrls.isEmpty) {
      return Image.asset(
        'assets/none1.jpg',
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    }

    final String firstImage = imageUrls[0].toString();

    if (firstImage.startsWith('http')) {
      return Image.network(
        firstImage,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    } else if (firstImage.startsWith('assets/')) {
      return Image.asset(
        firstImage,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    } else {
      return Image.file(
        File(firstImage),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserUid == null) {
      return const Scaffold(
        body: Center(child: Text("로그인이 필요합니다.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '관심 목록',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('likes', arrayContains: currentUserUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("좋아요한 게시물이 없습니다."));
          }

          final likedPosts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: likedPosts.length,
            itemBuilder: (context, index) {
              final post = likedPosts[index];
              final postData = post.data() as Map<String, dynamic>;
              final postId = post.id;
              final imageUrls = postData['imageUrls'] ?? [];
              final title = postData['title'] ?? '';
              final location = postData['location'] ?? '온라인';
              final headcount = postData['headcount']?.toString() ?? '?';
              final tags = postData['tags'] ?? [];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PostScreen(postData: postData, postId: postId),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildPostImage(imageUrls),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('requests')
                                  .where('postId', isEqualTo: postId)
                                  .where('status', isEqualTo: '수락함')
                                  .snapshots(),
                              builder: (context, requestSnapshot) {
                                final currentCount =
                                    requestSnapshot.data?.docs.length ?? 0;
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$title ($currentCount/$headcount)',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(location,
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: List.generate(
                                tags.length,
                                (i) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Text('#${tags[i]}',
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .update({
                            'likes': FieldValue.arrayRemove([currentUserUid])
                          });
                        },
                        child: Image.asset(
                          'assets/hheart.png',
                          width: 24,
                          height: 24,
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
}

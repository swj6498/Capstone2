import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyReviewList extends StatefulWidget {
  const MyReviewList({super.key});

  @override
  State<MyReviewList> createState() => _MyReviewListState();
}

class _MyReviewListState extends State<MyReviewList> {
  String? myNickname;

  Widget _buildPostImage(List<dynamic>? imageUrls) {
    if (imageUrls == null ||
        imageUrls.isEmpty ||
        imageUrls[0].toString().startsWith('assets/')) {
      return Image.asset(
        'assets/none1.jpg',
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrls[0],
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMyNickname();
  }

  Future<void> _loadMyNickname() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      myNickname = userDoc['nickname'];
    });
  }

  Widget _buildReviewTile(
      String imagePath, String title, String content, int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFF8F8F8), // 회색 배경
          borderRadius: BorderRadius.circular(12), // 둥근 테두리
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagePath.startsWith('http')
                  ? Image.network(imagePath,
                      width: 70, height: 70, fit: BoxFit.cover)
                  : Image.asset(imagePath,
                      width: 70, height: 70, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < rating ? Icons.star : Icons.star,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (myNickname == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // 배경 흰색
      appBar: AppBar(
        title: const Text(
          '내 후기',
          style: TextStyle(
            color: Color(0xFF7F71FC),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF7F71FC),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('writerRealNickname', isEqualTo: myNickname)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data!.docs;

          if (reviews.isEmpty) {
            return const Center(child: Text('작성한 후기가 없습니다.'));
          }

          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final data = reviews[index].data() as Map<String, dynamic>;
              final comment = data['content'] ?? '';
              final title = data['postTitle'] ?? '';
              final rating = data['rating'] ?? 0;
              final postId = data['postId'] ?? '';

              // ✅ postId가 비어있으면 기본 이미지로 처리
              if (postId.isEmpty) {
                return _buildReviewTile(
                    'assets/none1.jpg', title, comment, rating);
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .get(),
                builder: (context, postSnap) {
                  if (!postSnap.hasData || !postSnap.data!.exists) {
                    return _buildReviewTile(
                        'assets/none1.jpg', title, comment, rating);
                  }

                  final postData =
                      postSnap.data!.data() as Map<String, dynamic>;
                  final imageUrls = postData['imageUrls'] ?? [];

                  return _buildReviewTile(
                    imageUrls.isNotEmpty ? imageUrls[0] : 'assets/none1.jpg',
                    title,
                    comment,
                    rating,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

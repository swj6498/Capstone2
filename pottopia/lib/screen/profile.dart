
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Post.dart';

// ✅ 점 인디케이터 클래스
class DotIndicator extends Decoration {
  final Color color;

  const DotIndicator({required this.color});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DotPainter(color);
  }
}

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
    width: 80,
    height: 80,
    fit: BoxFit.cover,
  );
}

class _DotPainter extends BoxPainter {
  final Color color;

  _DotPainter(this.color);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double radius = 3; // 점 크기 줄임
    final double x = offset.dx + configuration.size!.width / 2;
    final double y = offset.dy + configuration.size!.height - 8; // 더 위로!

    canvas.drawCircle(Offset(x, y), radius, paint);
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? introduction;
  double? averageRating;
  int reviewCount = 0;

  Future<void> fetchAverageRating() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('postOwnerUid', isEqualTo: uid)
        .get();

    if (snapshot.docs.isEmpty) {
      print("❗ 받은 리뷰가 없습니다.");
      return;
    }

    final ratings = snapshot.docs.map((doc) => doc['rating'] as int).toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    setState(() {
      averageRating = double.parse(avg.toStringAsFixed(1)); // ✅ 이거 필요함!
      reviewCount = ratings.length;
    });

    print("⭐ 내가 받은 평균 별점: $averageRating (총 $reviewCount개)");
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
      if (doc.exists && doc.data()!.containsKey('introduction')) {
        setState(() {
          introduction = doc['introduction'];
        });
      }
    });
    fetchAverageRating();
  }

  @override
  Widget build(BuildContext context) {
    final String nickname =
        ModalRoute.of(context)!.settings.arguments as String;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black),
                onSelected: (value) {
                  if (value == 'edit_intro') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) {
                        final TextEditingController _controller =
                            TextEditingController();
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 24,
                            left: 20,
                            right: 20,
                            top: 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '소개 수정하기',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _controller,
                                maxLines: null,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: '새로운 소개를 입력하세요',
                                  filled: true,
                                  fillColor: Color(0xFFF7F7F7),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF7B61FF), width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B61FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  onPressed: () async {
                                    final uid =
                                        FirebaseAuth.instance.currentUser!.uid;
                                    final newIntro = _controller.text.trim();

                                    if (newIntro.isEmpty) {
                                      print("❗ 소개글이 비어있습니다.");
                                      return;
                                    }

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .set(
                                            {
                                          'introduction': newIntro,
                                        },
                                            SetOptions(
                                                merge:
                                                    true)); // 🔥 Firestore에 병합 저장

                                    setState(() {
                                      introduction = newIntro; // 🔄 상태 업데이트
                                    });

                                    Navigator.pop(context); // 다이얼로그 닫기
                                  },
                                  child: const Text(
                                    '저장',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit_intro',
                    child: Text('소개글 수정하기'),
                  ),
                ],
              ),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),

            // 프로필 이미지
            ClipOval(
              child: Image.asset(
                'assets/profile_picture.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 12),

            // 닉네임 (닉네임만 볼드, "님"은 일반)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: nickname,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const TextSpan(
                    text: ' 님',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 별점
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                if (averageRating == null) {
                  return const Icon(Icons.star_border,
                      color: Colors.amber, size: 30);
                }

                final filled = index + 1 <= averageRating!;
                final halfFilled =
                    index < averageRating! && averageRating! < index + 1;

                if (filled) {
                  return const Icon(Icons.star,
                      color: Colors.amber, size: 30); // ⭐
                } else if (halfFilled) {
                  return const Icon(Icons.star_half,
                      color: Colors.amber, size: 30); // ✨
                } else {
                  return const Icon(Icons.star_border,
                      color: Colors.amber, size: 30); // ☆
                }
              }),
            ),

            const SizedBox(height: 4),
            if (averageRating != null)
              Text(
                '$averageRating · 후기 $reviewCount',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),

            const SizedBox(height: 12),

            // 소개 문단
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '$introduction',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 12),

            // TabBar (커스텀 인디케이터 사용)
            const TabBar(
              labelColor: Color(0xFF7F71FC),
              unselectedLabelColor: Colors.black54,
              labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              indicator: DotIndicator(color: Color(0xFF7F71FC)),
              indicatorWeight: 0, // 점 인디케이터니까 밑줄 제거
              tabs: [Tab(text: '작성게시물'), Tab(text: '후기')],
            ),

            const Divider(height: 1, color: Color(0xFF7F71FC), thickness: 1),
            const SizedBox(height: 16), // ← 추가된 여백

            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('ownerName',
                            isEqualTo: nickname) // ← 프로필 주인 닉네임으로 필터
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('게시물이 없습니다.'));
                      }

                      final posts = snapshot.data!.docs;
                      print('현재 프로필 nickname: $nickname');

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final data =
                              posts[index].data() as Map<String, dynamic>;
                          final postId = posts[index].id;
                          final maxCount = data['headcount'] ?? 0;

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('requests')
                                .where('postId', isEqualTo: postId)
                                .where('status',
                                    isEqualTo: '수락함') // 또는 수락함 포함하려면 조건 변경
                                .snapshots(),
                            builder: (context, snapshot) {
                              final currentCount =
                                  snapshot.data?.docs.length ?? 0;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PostScreen(
                                        postData: {
                                          ...data,
                                          'postId': postId,
                                        },
                                        postId: postId,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                        255, 247, 247, 247),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child:
                                            _buildPostImage(data['imageUrls']),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${data['title']} ($currentCount/$maxCount)',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on,
                                                    size: 16,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(data['location'] ?? '',
                                                    style: const TextStyle(
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              children: List.generate(
                                                (data['tags'] ?? []).length,
                                                (i) {
                                                  final tag =
                                                      (data['tags'] ?? [])[i];
                                                  return Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade400),
                                                    ),
                                                    child: Text('#$tag',
                                                        style: const TextStyle(
                                                            fontSize: 12)),
                                                  );
                                                },
                                              ),
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
                      );
                    },
                  ),
                  // 후기 탭
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reviews')
                        .where('targetNickname', isEqualTo: nickname)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('에러 발생: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('등록된 후기가 없습니다.'));
                      }

                      final reviews = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final data =
                              reviews[index].data() as Map<String, dynamic>;
                          final content = data['content'] ?? '';
                          final rating = data['rating']?.toString() ?? '-';
                          final date =
                              (data['timestamp'] as Timestamp).toDate();
                          final writerName = data['writerRealNickname'] ?? '익명';
                          print('리뷰 작성자 닉네임: ${data['writerRealNickname']}');
                          final postTitle = data['postTitle'] ?? '관련 게시물';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 247, 247, 247),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                      'assets/profile_picture.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '$writerName',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        postTitle,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7F71FC)),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            Icons.star,
                                            size: 18,
                                            color: i < int.tryParse(rating)!
                                                ? Colors.amber
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(content),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
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

// 게시물 카드 위젯
class PostCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String member;
  final String image;

  const PostCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.member,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image.startsWith('http')
              ? Image.network(image, width: 48, height: 48, fit: BoxFit.cover)
              : Image.asset(image, width: 48, height: 48, fit: BoxFit.cover),
        ),
        title: Text('$title $member'),
        subtitle: Row(
          children: [
            const Icon(Icons.location_on, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

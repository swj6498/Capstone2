import 'package:flutter/material.dart';
import 'RequestScreen.dart';
import 'ChatScreen.dart';
import 'MypageScreen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'PostList.dart';
import 'Search.dart';
import 'PostCreate.dart';
import 'notice_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Post.dart';
import 'Mapscreen.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double? _currentLat;
  double? _currentLng;
  String _selectedAddress = '';

  List<Map<String, dynamic>> recentPosts = []; // ✅ 여기에 추가
  final PageController recentPageController = PageController();

  final PageController _interestPageController = PageController(
    viewportFraction: 1.0,
  );
  final PageController _noticePageController = PageController(
    viewportFraction: 1.0,
  );
  int _selectedIndex = 0;

  Future<void> saveUserLocation(String uid, double lat, double lng) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'lat': lat,
      'lng': lng,
    }, SetOptions(merge: true));
  }

  Future<int> getCurrentPeople(String postId, String ownerId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('requests')
        .where('postId', isEqualTo: postId)
        .get();

    final acceptedCount = snapshot.docs.length;
    // ✅ 작성자는 무조건 포함 → 최소 1명부터 시작
    return acceptedCount + 1;
  }

  Future<void> fetchRecentPosts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('❌ 로그인된 사용자 없음');
      return;
    }

    print('📌 현재 사용자 UID: $uid');

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recentPosts')
        .orderBy('viewedAt', descending: true)
        .limit(10)
        .get();

    print('📥 불러온 최근 본 게시물 수: ${snapshot.docs.length}');

    final postFutures = snapshot.docs.map((doc) async {
      final postId = doc['postId'];
      print('🔍 최근 본 postId: $postId');
      final viewedAt = doc['viewedAt']; // 🔥 viewedAt 가져오기

      final postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();

      if (postSnapshot.exists && postSnapshot.data() != null) {
        final postData = postSnapshot.data()!;
        postData['postId'] = postId;
        print('✅ 게시물 데이터 로드 완료: ${postData['title']}');
        postData['viewedAt'] = viewedAt; // ✅ 이 줄을 반드시 추가하세요!

        // ✅ 여기에 강제로 가져오기
        final ownerId = postSnapshot.data()!['ownerId'];
        print('📌 ownerId 강제 추출: $ownerId');

        final currentcount = await getCurrentPeople(postId, ownerId);
        postData['currentcount'] = currentcount;
        postData['ownerId'] = ownerId; // 필요하면 postData에도 넣기
        print('📌 ownerId 강제 추출: $ownerId'); // ✅ 이거 꼭 추가!

        return postData;
      } else {
        print('⚠️ 게시물이 존재하지 않음 or 삭제됨: $postId');
        return null;
      }
    }).toList();

    final postList = await Future.wait(postFutures);

    postList.removeWhere((post) => post == null);

    // 🔥 최신순 정렬 (viewedAt 기준)
    postList.sort((a, b) {
      final aTime = a!['viewedAt'] as Timestamp?;
      final bTime = b!['viewedAt'] as Timestamp?;
      return bTime!.compareTo(aTime!);
    });

    setState(() {
      recentPosts = postList
          .where((element) => element != null)
          .cast<Map<String, dynamic>>()
          .toList();
    });

    print('📦 최종 recentPosts 길이: ${recentPosts.length}');
    for (var post in recentPosts) {
      print('📝 최근 게시물 제목: ${post['title']}');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchRecentPosts(); // ✅ recentPosts 가져오는 함수 호출
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    Widget selectedContent;
    if (_selectedIndex == 0) {
      selectedContent = Column(
        children: [
          // 1. 내 위치 추가하기 버튼
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.015,
            ),
            child: SizedBox(
              width: double.infinity,
              child: _selectedAddress.isEmpty
                  ? ElevatedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('내 위치 추가하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F71FC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MapScreen()),
                        );
                        if (result != null) {
                          setState(() {
                            _selectedAddress = result['address'];
                            _currentLat = result['lat'];
                            _currentLng = result['lng'];
                          });
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null &&
                              _currentLat != null &&
                              _currentLng != null) {
                            await saveUserLocation(
                              uid,
                              _currentLat!,
                              _currentLng!,
                            );
                          }
                        }
                      },
                    )
                  : GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MapScreen()),
                        );
                        if (result != null) {
                          setState(() {
                            _selectedAddress = result['address'];
                            _currentLat = result['lat'];
                            _currentLng = result['lng'];
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F71FC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            _selectedAddress,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          Expanded(
            child: _HomeContent(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              interestPageController: _interestPageController,
              noticePageController: _noticePageController,
              recentPosts: recentPosts,
              recentPageController: recentPageController,
              fetchRecentPosts: fetchRecentPosts, // ✅ 추가
            ),
          ),
        ],
      );
    } else if (_selectedIndex == 1) {
      selectedContent = const RequestScreen();
    } else if (_selectedIndex == 2) {
      selectedContent = const ChatScreen();
    } else {
      selectedContent = const MypageScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white, // ✅ 배경 흰색

      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              title: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '팟',
                      style: TextStyle(
                        color: Color(0xFF775DF8),
                        fontWeight: FontWeight.bold, // ← '팟'만 더 굵게
                      ),
                    ),
                    TextSpan(
                      text: 'topia',
                      style: TextStyle(color: Color(0xFF775DF8)),
                    ),
                  ],
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  child: const Icon(Icons.search, color: Colors.black),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.notifications_none, color: Colors.black),
                const SizedBox(width: 16),
              ],
            ),

      // ✅ 게시물 작성 버튼
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PostCreateScreen(),
                  ),
                ); // 작성 페이지 이동
              },
              backgroundColor: const Color.fromARGB(255, 135, 119, 228),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,

      body: selectedContent,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFF5F5F5),
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              width: _selectedIndex == 0 ? 40 : 34,
              height: _selectedIndex == 0 ? 40 : 34,
              child: Image.asset(
                _selectedIndex == 0
                    ? 'assets/homepoint.png'
                    : 'assets/home.png',
                fit: BoxFit.contain,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: _selectedIndex == 1 ? 40 : 34,
              height: _selectedIndex == 1 ? 40 : 34,
              child: Image.asset(
                _selectedIndex == 1
                    ? 'assets/checkpoint.png'
                    : 'assets/check.png',
                fit: BoxFit.contain,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: _selectedIndex == 2 ? 40 : 34,
              height: _selectedIndex == 2 ? 40 : 34,
              child: Image.asset(
                _selectedIndex == 2
                    ? 'assets/chatpoint.png'
                    : 'assets/chat.png',
                fit: BoxFit.contain,
              ),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: _selectedIndex == 3 ? 40 : 34,
              height: _selectedIndex == 3 ? 40 : 34,
              child: Image.asset(
                _selectedIndex == 3
                    ? 'assets/mypagepoint.png'
                    : 'assets/mypage.png',
                fit: BoxFit.contain,
              ),
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final double screenHeight;
  final double screenWidth;
  final PageController interestPageController;
  final PageController noticePageController;
  final List<Map<String, dynamic>> recentPosts;
  final PageController recentPageController;
  final VoidCallback fetchRecentPosts; // ✅ 이거 추가

  const _HomeContent({
    required this.screenHeight,
    required this.screenWidth,
    required this.interestPageController,
    required this.noticePageController,
    required this.recentPosts,
    required this.recentPageController,
    required this.fetchRecentPosts, // ✅ 이거도 추가
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: screenHeight * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CategoryIcon(
                  imagePath: 'assets/study.png',
                  label: '스터디',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PostListScreen(category: '스터디팟'),
                      ),
                    );
                  },
                ),
                _CategoryIcon(
                  imagePath: 'assets/health.png',
                  label: '운동/스포츠',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PostListScreen(category: '운동팟'),
                      ),
                    );
                  },
                ),
                _CategoryIcon(
                  imagePath: 'assets/shopping.png',
                  label: '공동구매',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PostListScreen(category: '공구팟'),
                      ),
                    );
                  },
                ),
                _CategoryIcon(
                  imagePath: 'assets/hobby.png',
                  label: '취미',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PostListScreen(category: '취미팟'),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.03),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/clock.png', width: 24, height: 24),
                    const SizedBox(width: 7),
                    const Text(
                      '최근 본 게시물',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('recentPosts')
                      .orderBy('viewedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final recentDocs = snapshot.data!.docs;

                    if (recentDocs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('최근 본 게시물이 없습니다.'),
                      );
                    }

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: Future.wait(
                        recentDocs.map((doc) async {
                          final postId = doc['postId'];
                          final viewedAt = doc['viewedAt'];
                          final postSnap = await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .get();

                          if (postSnap.exists && postSnap.data() != null) {
                            final postData = postSnap.data()!;
                            postData['postId'] = postId;
                            postData['viewedAt'] = viewedAt;
                            return postData;
                          }
                          return {}; // 삭제된 경우
                        }),
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final recentPosts = snapshot.data!
                            .where((e) => e.isNotEmpty)
                            .toList();

                        return Container(
                          height: 180,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 247, 247, 247),
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  controller: recentPageController,
                                  itemCount: recentPosts.length > 5
                                      ? 5
                                      : recentPosts.length,
                                  itemBuilder: (context, index) {
                                    final post = recentPosts[index];
                                    final postId = post['postId'];
                                    final maxCount = post['headcount'] ?? 0;

                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('requests')
                                          .where('postId', isEqualTo: postId)
                                          .where('status', isEqualTo: '수락함')
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final acceptedCount =
                                            snapshot.data?.docs.length ?? 0;
                                        final currentCount = 1 + acceptedCount;

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PostScreen(
                                                  postData: post,
                                                  postId: post['postId'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: _InterestContent(
                                            title: post['title'],
                                            location: post['location'],
                                            people:
                                                '($currentCount/$maxCount)', // ✅ 실시간 반영
                                            content:
                                                post['content'] ?? '내용이 없습니다.',
                                            imageUrls: post['imageUrls'],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              SmoothPageIndicator(
                                controller: recentPageController,
                                count: recentPosts.length > 5
                                    ? 5
                                    : recentPosts.length,
                                effect: WormEffect(
                                  dotHeight: 6,
                                  dotWidth: 6,
                                  activeDotColor: Color(0xFF7F71FC),
                                  dotColor: Colors.grey.shade300,
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
            SizedBox(height: screenHeight * 0.01),
            Row(
              children: [
                Image.asset('assets/notice.png', width: 24, height: 24),
                const SizedBox(width: 7),
                const Text(
                  "공지사항",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 247, 247, 247),
                borderRadius: BorderRadius.circular(23),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notices')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final notices = snapshot.data!.docs;
                  return Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: noticePageController,
                          itemCount: notices.length,
                          itemBuilder: (context, index) {
                            final notice = notices[index];
                            final data = notice.data() as Map<String, dynamic>;
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NoticeDetailScreen(
                                      title: data['title'],
                                      content: data['content'],
                                      author: data['author'],
                                      createdAt:
                                          (data['createdAt'] as Timestamp)
                                              .toDate(),
                                    ),
                                  ),
                                );
                              },
                              child: _NoticeContent(
                                title: data['title'],
                                content: data['content'],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SmoothPageIndicator(
                        controller: noticePageController,
                        count: notices.length,
                        effect: WormEffect(
                          dotHeight: 6,
                          dotWidth: 6,
                          activeDotColor: Color(0xFF7F71FC),
                          dotColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  const _CategoryIcon({
    required this.imagePath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Color.fromRGBO(186, 184, 201, 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _InterestContent extends StatelessWidget {
  final String title;
  final String location;
  final String people;
  final String content;
  final List<dynamic>? imageUrls; // ✅ 추가

  const _InterestContent({
    required this.title,
    required this.location,
    required this.people,
    required this.content,
    this.imageUrls, // ✅ 추가
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⬅ 이미지 (왼쪽 위)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPostImage(imageUrls),
            ),
            const SizedBox(width: 12),

            // ➡ 제목 + 인원수 + 위치 (오른쪽)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title $people',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ⬇ 설명 텍스트 (아래쪽)
        Align(
          alignment: Alignment.centerLeft,
          child: Text(content, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

class _NoticeContent extends StatelessWidget {
  final String title;
  final String content;

  const _NoticeContent({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

// ✅ PostTile 위젯 정의
class PostTile extends StatelessWidget {
  final Map<String, dynamic> postData;

  const PostTile({Key? key, required this.postData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(postData['title'] ?? '제목 없음'),
      subtitle: Text(postData['location'] ?? '위치 정보 없음'),
    );
  }
}

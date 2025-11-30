import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Post.dart';
import 'dart:math';


class PostListScreen extends StatefulWidget {
  final String category; // ✅ 추가

  const PostListScreen({
    super.key,
    required this.category, // ✅ 생성자에 category 추가
  });

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final List<String> categories = ['스터디팟', '운동팟', '공구팟', '취미팟'];
  int selectedCategoryIndex = 0;

  final List<String> filters = ['거리순', '온라인', '최신순'];
  String selectedFilter = '거리순';
  final Map<String, bool> likedPosts = {};

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

  //온라인
  Stream<QuerySnapshot> getPostStream() {
    if (selectedFilter == '온라인') {
      return FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: categories[selectedCategoryIndex])
          .where('isOnline', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: categories[selectedCategoryIndex])
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  //거리계산 함수
  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km 단위
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLng = (lng2 - lng1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    // category에 맞는 인덱스 자동 설정
    final passedCategory = widget.category;
    final index = categories.indexOf(passedCategory);
    if (index != -1) {
      selectedCategoryIndex = index;
    }
    _preloadLikes();
    _loadUserLocation();
  }

  Future<void> _preloadLikes() async {
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final postsSnapshot =
        await FirebaseFirestore.instance.collection('posts').get();

    for (var doc in postsSnapshot.docs) {
      final likes = doc.data()['likes'] as List?;
      likedPosts[doc.id] = likes?.contains(currentUserUid) ?? false;
    }

    setState(() {});
  }

  Future<void> _loadUserLocation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _currentLat = userDoc.data()?['lat'] as double?;
          _currentLng = userDoc.data()?['lng'] as double?;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final isCurrentlyLiked = likedPosts[postId] ?? false;

    if (isCurrentlyLiked) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([currentUserUid])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([currentUserUid])
      });
    }

    setState(() {
      likedPosts[postId] = !isCurrentlyLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("🔍 widget.category: '${widget.category}'"); // 여기에 추가
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(255, 255, 255, 1.0),
        elevation: 0.5,
        leading: IconButton(
          icon: Image.asset('assets/back.png', width: 24, height: 24),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Image.asset('assets/home2.png', width: 24, height: 24),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 카테고리 탭
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(categories.length, (index) {
                final isSelected = selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategoryIndex = index; // 카테고리 값 변경 시 화면 갱신
                    });
                  },
                  child: Column(
                    children: [
                      Text(
                        categories[index],
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF7F71FC)
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isSelected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF7F71FC),
                          ),
                        ),
                      if (!isSelected) const SizedBox(height: 6), // 높이 맞춤용
                    ],
                  ),
                );
              }),
            ),
          ),

          // ✅ 보라색 하단 줄
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFF7F71FC),
            ),
          ),

          // ✅ 드롭다운 필터 (오른쪽)
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    items: [
                      DropdownMenuItem(
                        value: selectedFilter,
                        child: Text(
                          selectedFilter,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...filters
                          .where((f) => f != selectedFilter) // 선택된 항목 제외
                          .map(
                            (filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(
                                filter,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal),
                              ),
                            ),
                          )
                          .toList(),
                    ],
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedFilter = newValue;
                        });
                      }
                    },
                    underline: Container(),
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: Colors.white,
                    borderRadius:
                        BorderRadius.circular(12), // ✅ 펼쳐지는 리스트 모서리 둥글게
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          

          // ✅ 게시물 리스트
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getPostStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('게시물이 없습니다.'));
                }

                final posts = snapshot.data!.docs;
                // 거리 계산 및 임시 리스트 생성
                final postsWithDistance = posts.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final geo = data['geo'] as GeoPoint?;
                  if (geo != null &&
                      _currentLat != null &&
                      _currentLng != null) {
                    return {
                      'doc': doc,
                      'distance': _calculateDistance(
                        _currentLat!,
                        _currentLng!,
                        geo.latitude,
                        geo.longitude,
                      ),
                    };
                  } else {
                    return {'doc': doc, 'distance': double.infinity};
                  }
                }).toList();

                // 거리순 정렬 (가까운 순)
                if (selectedFilter == '거리순' &&
                    _currentLat != null &&
                    _currentLng != null) {
                  postsWithDistance.sort((a, b) {
                    final distanceA =
                        (a['distance'] as double?) ?? double.infinity;
                    final distanceB =
                        (b['distance'] as double?) ?? double.infinity;
                    return distanceA.compareTo(distanceB);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final doc = postsWithDistance[index]['doc']
                        as QueryDocumentSnapshot<Map<String, dynamic>>;
                    final data = doc.data();
                    final postId = doc.id;
                    final maxCount = data['headcount'] ?? 0;
                    final isLiked = likedPosts[postId] ?? false;
                    final distance = (postsWithDistance[index]['distance'] as double?) ?? double.infinity;

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('requests')
                          .where('postId', isEqualTo: postId)
                          .where('status', isEqualTo: '수락함') // 또는 수락함 포함하려면 조건 변경
                          .snapshots(),
                      builder: (context, snapshot) {
                        final currentCount = snapshot.data?.docs.length ?? 0;

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
                              color: const Color.fromARGB(255, 247, 247, 247),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${data['title']} ($currentCount/$maxCount)',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              _toggleLike(postId);
                                            },
                                            child: Image.asset(
                                              isLiked
                                                  ? 'assets/hheart.png'
                                                  : 'assets/love.png',
                                              width: 20,
                                              height: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 16, color: Colors.grey),
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
                                            final tag = (data['tags'] ?? [])[i];
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade400),
                                              ),
                                              child: Text('#$tag',
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            );
                                          },
                                        ),
                                      ),
                                      // 거리 표시 추가
                                      // Text(
                                      //   '거리: ${distance == double.infinity ? "알 수 없음" : distance.toStringAsFixed(2) + " km"}',
                                      //   style: const TextStyle(
                                      //       color: Colors.grey, fontSize: 12),
                                      // )
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
          )
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final String title;
  final String people;
  final String location;
  final String imagePath;

  const PostCard({
    super.key,
    required this.title,
    required this.people,
    required this.location,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
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
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imagePath,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title ($people)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(location, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

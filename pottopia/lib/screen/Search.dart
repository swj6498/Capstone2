import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Post.dart';
import 'dart:math';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedCategory = '전체';
  String selectedFilter = '제목+내용';
  String selectedSort = '최신순'; // '인기순'을 '온라인'으로 바꿈

  List<QueryDocumentSnapshot> filteredPosts = [];
  List<String> recentSearches = [];
  bool isLoading = false;

  final List<String> categories = ['전체', '스터디팟', '운동팟', '공구팟', '취미팟'];
  final List<String> filters = ['제목', '제목+내용', '내용'];
  final List<String> sortOptions = ['최신순', '온라인', '거리순']; // '인기순'을 '온라인'으로 변경

  double? _currentLat;
  double? _currentLng;

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

  //거리순

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // km 단위
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLng = (lng2 - lng1) * (pi / 180);
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
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

  // 온라인 필터링 추가
  Stream<QuerySnapshot> getPostStream() {
    if (selectedSort == '온라인') {
      return FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: selectedCategory)
          .where(
            'isOnline',isEqualTo: true,) // 'isOnline' 필드를 기준으로 온라인 게시물만 가져오기
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: selectedCategory)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _loadRecentSearches();
  }

  void _loadRecentSearches() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('searchHistory')
          .orderBy('searchedAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        recentSearches = snapshot.docs
            .map((doc) => doc['keyword'].toString())
            .toList();
      });
    }
  }

  void _addRecentSearch(String keyword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('searchHistory')
          .doc(keyword);

      await docRef.set({
        'keyword': keyword,
        'searchedAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      recentSearches.remove(keyword);
      recentSearches.insert(0, keyword);
      if (recentSearches.length > 10) {
        recentSearches.removeLast();
      }
    });
  }

  void _removeRecentSearch(String keyword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('searchHistory')
          .doc(keyword)
          .delete();
    }

    setState(() {
      recentSearches.remove(keyword);
    });
  }

  void _performSearch(String keyword) async {
    setState(() {
      isLoading = true;
      filteredPosts = [];
    });

    Query query = FirebaseFirestore.instance.collection('posts');
    if (selectedCategory != '전체') {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    
    // ✅ '온라인' 정렬일 때 isOnline 필터 추가
    if (selectedSort == '온라인') {
    query = query.where('isOnline', isEqualTo: true);
  }

    final snapshot = await query.get();
    final input = keyword.toLowerCase().trim();
    final words = input
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    final results = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final content = (data['content'] ?? '').toString().toLowerCase();
      final tags =
          (data['tags'] as List?)?.map((e) => e.toString().toLowerCase()) ?? [];
      final category = (data['category'] ?? '').toString();

      if (selectedCategory != '전체' && category != selectedCategory) {
        return false;
      }

      for (final word in words) {
        if (word.startsWith('#')) {
          final tag = word.substring(1);
          if (!tags.any((t) => t.contains(tag))) {
            return false;
          }
        } else {
          final inTitle = title.contains(word);
          final inContent = content.contains(word);
          if (selectedFilter == '제목' && !inTitle) return false;
          if (selectedFilter == '내용' && !inContent) return false;
          if (selectedFilter == '제목+내용' && !inTitle && !inContent) return false;
        }
      }

      return true;
    }).toList();

    // 거리순 정렬
    if (selectedSort == '거리순' && _currentLat != null && _currentLng != null) {
      final postsWithDistance = results.map((doc) {
        final data = doc.data() as Map;
        final geo = data['geo'] as GeoPoint?;
        if (geo != null) {
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

      postsWithDistance.sort((a, b) {
        final distanceA = (a['distance'] as double?) ?? double.infinity;
        final distanceB = (b['distance'] as double?) ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        filteredPosts = postsWithDistance
            .map((e) => e['doc'] as QueryDocumentSnapshot<Object?>)
            .toList();
        isLoading = false;
      });
      return;
    }

    // 최신순/온라인 정렬
    if (selectedSort == '최신순') {
      results.sort((a, b) {
        final aData = a.data() as Map;
        final bData = b.data() as Map;
        return (bData['createdAt'] as Timestamp).compareTo(
          aData['createdAt'] as Timestamp,
        );
      });
    }
    setState(() {
      isLoading = false;
      filteredPosts = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedOptions = [
      selectedSort,
      ...sortOptions.where((option) => option != selectedSort),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/back.png', width: 24, height: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              hintText: '검색어를 입력하세요',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFF775DF8)),
                onPressed: () {
                  final keyword = _searchController.text.trim();
                  if (keyword.isNotEmpty) {
                    _addRecentSearch(keyword);
                    _performSearch(keyword);
                  }
                },
              ),
              contentPadding: const EdgeInsets.only(left: 19, right: 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color.fromARGB(255, 239, 238, 242),
            ),
            onSubmitted: (value) {
              final keyword = value.trim();
              if (keyword.isNotEmpty) {
                _addRecentSearch(keyword);
                _performSearch(keyword);
              }
            },
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: recentSearches.map((keyword) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            _searchController.text = keyword;
                            _performSearch(keyword);
                          },
                          child: Chip(
                            label: Text(keyword),
                            deleteIcon: const Icon(Icons.close),
                            onDeleted: () => _removeRecentSearch(keyword),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 27),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                    });
                    final keyword = _searchController.text.trim();
                    if (keyword.isNotEmpty) _performSearch(keyword);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF775DF8)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        if (isSelected) const SizedBox(width: 4),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSort,
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(color: Colors.black),
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: Colors.white,
                    items: sortedOptions.map((sort) {
                      return DropdownMenuItem<String>(
                        value: sort,
                        child: Text(sort),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSort = value;
                        });
                        final keyword = _searchController.text.trim();
                        if (keyword.isNotEmpty) _performSearch(keyword);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (!isLoading && filteredPosts.isEmpty)
            const Center(child: Text('게시물이 없습니다.')),
          if (!isLoading && filteredPosts.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredPosts.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredPosts[index].data() as Map<String, dynamic>;
                  final postId = filteredPosts[index].id;
                  final maxCount = data['headcount'] ?? 0;

                  return FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('requests')
                        .where('postId', isEqualTo: postId)
                        .where('status', isEqualTo: '수락함')
                        .get(),
                    builder: (context, snapshot) {
                      final acceptedDocs = snapshot.data?.docs ?? [];

                      // 작성자 포함해서 항상 1명부터 시작
                      final currentCount = 1 + acceptedDocs.length;

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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildPostImage(data['imageUrls']),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${data['title']}',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // 인원수
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                            right: 8.0,
                                          ), // ✅ 간격 부여
                                          child: Text(
                                            '($currentCount / $maxCount)',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Image.asset(
                                          'assets/love.png',
                                          width: 20,
                                          height: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            data['location'] ?? '위치 미제공',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            child: Text(
                                              '#$tag',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
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
              ),
            ),
        ],
      ),
    );
  }
}

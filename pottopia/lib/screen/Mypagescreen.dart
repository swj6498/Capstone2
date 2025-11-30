import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'NoticeWriteScreen.dart';
import 'Login.dart';
import 'delete_confirm_dialog.dart';
import 'MyPostList.dart';
import 'Favoritepost.dart';
import 'MyReviewList.dart';
import 'EditProfileScreen.dart';
import 'profile.dart';

// 전역 설정 상수
const double kIconSize = 35;
const double kFontSize = 18;
const Color kLabelColor = Color(0xFF545454);

const double kSettingIconSize = 37;
const double kSettingFontSize = 18;
const double kSettingItemSpacing = 20;

class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  String nickname = '';
  bool isAdmin = false;
  bool isLoading = true;
  double? averageRating;
  int reviewCount = 0;

  Future<void> fetchAverageRating() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('postOwnerUid', isEqualTo: uid)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final ratings = snapshot.docs.map((doc) => doc['rating'] as int).toList();
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;

      setState(() {
        averageRating = double.parse(avg.toStringAsFixed(1));
        reviewCount = ratings.length;
      });
    }
  }

  Future<void> _fetchUserDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          nickname = data['nickname'] ?? '닉네임 없음';
          isAdmin = data['isAdmin'] == true;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    try {
      // Firestore 유저 데이터 삭제
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      }

      // Firebase Auth 계정 삭제
      if (user != null) {
        await user.delete();
      }

      // 탈퇴 후 로그인 화면 등으로 이동 (예시)
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // 재인증 필요 안내
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('재인증 필요'),
            content: const Text('보안을 위해 최근 로그인 정보가 필요합니다.\n로그아웃 후 다시 로그인해주세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원 탈퇴 중 오류 발생: ${e.message}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원 탈퇴 중 오류 발생: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserDoc();
    fetchAverageRating();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 마이페이지 상단 타이틀 + 종 아이콘
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '마이페이지',
                    style: TextStyle(
                      fontSize: 25,
                      color: Color(0xFF7F71FC),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    iconSize: 28,
                    color: Color(0xFF303030),
                    onPressed: () {
                      // 알림 페이지 이동 기능 구현 가능
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 프로필, 닉네임, 로그아웃
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color.fromARGB(255, 255, 255, 255),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Image.asset(
                        'assets/woman.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                                settings: RouteSettings(arguments: nickname),
                              ),
                            );
                          },
                          child: Text(
                            '$nickname 님',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              if (averageRating == null) {
                                return const Icon(
                                  Icons.star_border,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }
                              final filled = index + 1 <= averageRating!;
                              final halfFilled =
                                  index < averageRating! &&
                                  averageRating! < index + 1;
                              if (filled) {
                                return const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              } else if (halfFilled) {
                                return const Icon(
                                  Icons.star_half,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              } else {
                                return const Icon(
                                  Icons.star_border,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }
                            }),
                            const SizedBox(width: 4),
                            Text(
                              averageRating != null
                                  ? '${averageRating!.toStringAsFixed(1)} · 후기 $reviewCount'
                                  : '별점 없음',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white, //
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color.fromARGB(255, 225, 225, 225),
                      ),
                    ),
                    child: TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, // ✅ 내부 텍스트 패딩 제거
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(
                          color: Color(0xFF775DF8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 아이콘 메뉴 (내 게시물 등)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyPostListScreen(),
                        ),
                      );
                    },
                    child: _buildRoundImageIcon(
                      context,
                      'assets/post.png',
                      '내 게시물',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FavoritePostScreen(),
                        ),
                      );
                    },
                    child: _buildRoundImageIcon(
                      context,
                      'assets/love.png',
                      '관심 목록',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyReviewList()),
                      );
                    },
                    child: _buildRoundImageIcon(
                      context,
                      'assets/review.png',
                      '내 후기',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 설정 리스트
              _buildImageSettingItem(context, 'assets/setting.png', '설정'),
              _buildImageSettingItem(
                context,
                'assets/tnwjd.png',
                '회원 정보 수정',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
              _buildImageSettingItem(
                context,
                'assets/sad.png',
                '회원 탈퇴',
                onTap: () {
                  showDeleteConfirmDialog(context, () async {
                    await _deleteAccount(context);
                  });
                },
              ),
              if (isAdmin)
                _buildImageSettingItem(
                  context,
                  'assets/admin.png',
                  '관리자',
                  onTap: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('notices')
                          .add({
                            'title': '임시 제목',
                            'content': '임시 내용입니다.',
                            'createdAt': FieldValue.serverTimestamp(),
                            'author': user.email,
                          });
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NoticeWriteScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundImageIcon(
    BuildContext context,
    String imagePath,
    String label,
  ) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromARGB(255, 243, 243, 245),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.none, // 이미지 크기를 유지
              child: Image.asset(
                imagePath,
                width: kIconSize,
                height: kIconSize,
                alignment: Alignment.center, // 중심 정렬
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: kFontSize,
            fontWeight: FontWeight.bold,
            color: kLabelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSettingItem(
    BuildContext context,
    String imagePath,
    String label, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: kSettingItemSpacing / 2),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: imagePath.contains('admin.png')
              ? const EdgeInsets.only(left: 24.0, right: 16.0)
              : const EdgeInsets.symmetric(horizontal: 16.0),
          leading: Image.asset(
            imagePath,
            width: imagePath.contains('admin.png') ? 30 : kSettingIconSize,
            height: imagePath.contains('admin.png') ? 30 : kSettingIconSize,
            fit: BoxFit.cover,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: kSettingFontSize,
              fontWeight: FontWeight.w500,
              color: kLabelColor,
            ),
          ),
          onTap: onTap ?? () {},
        ),
      ),
    );
  }
}

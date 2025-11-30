import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Chatscreen.dart';

class WriteReviewScreen extends StatefulWidget {
  final String chatId;
  final String targetNickname;
  final String postId;
  final String postTitle;
  final String postOwnerUid;

  const WriteReviewScreen({
    super.key,
    required this.chatId,
    required this.targetNickname,
    required this.postId,
    required this.postTitle,
    required this.postOwnerUid,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 5; // ⭐ 기본값: 매우 만족
  bool _isTextFieldFocused = false;
  final _controller = TextEditingController();
  String? postOwnerName; // 🔧 Firestore에서 가져올 게시물 작성자 닉네임

  final List<String> _ratingTexts = [
    '매우 불만족',
    '불만족',
    '조금 불만족',
    '보통',
    '조금 만족',
    '매우 만족',
  ];

  @override
  void initState() {
    super.initState();
    fetchPostOwnerName();
  }

  Future<void> fetchPostOwnerName() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .where('ownerId', isEqualTo: widget.postOwnerUid)
        .limit(1)
        .get();
    if (doc.docs.isNotEmpty) {
      setState(() {
        postOwnerName =
            doc.docs.first.data()['ownerName'] ?? widget.targetNickname;
      });
    } else {
      setState(() {
        postOwnerName = widget.targetNickname;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() {
      if (hasFocus) {
        _isTextFieldFocused = true;
      } else {
        if (_controller.text.isEmpty) {
          _isTextFieldFocused = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 120),
                    Text(
                      '[게시물] ${postOwnerName ?? widget.targetNickname} 님',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      '과 함께한 팟은 어떠셨나요?',
                      style: TextStyle(fontSize: 20, color: Colors.black),
                    ),
                    const SizedBox(height: 24),

                    // ⭐ 별점 표시 및 선택
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    // 별점에 따른 텍스트 표시
                    Text(
                      _ratingTexts[_rating],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),

                    const Spacer(),

                    // 📝 리뷰 입력창
                    Focus(
                      onFocusChange: _handleFocusChange,
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              _isTextFieldFocused ? '' : '만족하시는 이유를 작성해 주세요.',
                          hintStyle: const TextStyle(fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 제출 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final currentUser =
                              FirebaseAuth.instance.currentUser!;
                          final reviewText = _controller.text.trim();
                          final timestamp = Timestamp.now();

                          // ✅ 실제 닉네임 불러오기
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser.uid)
                              .get();
                          final realNickname =
                              userDoc.data()?['nickname'] ?? '알 수 없음';

                          // ✅ Firestore에 리뷰 저장
                          await FirebaseFirestore.instance
                              .collection('reviews')
                              .add({
                            'writerUid': currentUser.uid,
                            'writerRealNickname': realNickname,
                            'targetNickname':
                                postOwnerName ?? widget.targetNickname,
                            'rating': _rating,
                            'content': reviewText,
                            'timestamp': timestamp,
                            'postId': widget.postId,
                            'postTitle': widget.postTitle,
                            'postOwnerUid': widget.postOwnerUid,
                          });

                          // ✅ ChatScreen으로 이동
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7F71FC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '작성하기',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

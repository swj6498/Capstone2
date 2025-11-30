import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:share_plus/share_plus.dart';
import 'profile.dart';
import 'ChatRoomscreen.dart';

class PostScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostScreen({super.key, required this.postData, required this.postId});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  bool isLiked = false;

  final PageController _pageController = PageController();
  Map<String, dynamic>? post;

  @override
  void initState() {
    super.initState();
    post = widget.postData;

    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final likes = widget.postData['likes'] as List?;
    isLiked = likes?.contains(currentUserUid) ?? false;
    _loadPost();
  }

  Future<void> _loadPost() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    if (doc.exists) {
      setState(() {
        post = doc.data();
      });
    }
  }

  void _showRequestDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final ownerUid = widget.postData['ownerId'];

    // ✅ 작성자 본인은 신청할 수 없음
    if (currentUserUid == ownerUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자기 자신의 게시물에는 신청할 수 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('신청 메시지 입력'),
          content: TextField(
            controller: messageController,
            maxLength: 100,
            decoration: const InputDecoration(hintText: '예: 함께 참여하고 싶어요!'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();

                final userName = userDoc.data()?['nickname'] ?? '알 수 없음';

                await FirebaseFirestore.instance.collection('requests').add({
                  'postOwnerId': widget.postData['ownerId'],
                  'requesterId': user.uid,
                  'postId': widget.postData['postId'],
                  'requesterName': userName,
                  'postTitle': widget.postData['title'],
                  'image': widget.postData['image'],
                  'location': widget.postData['location'],
                  'isOnline': widget.postData['isOnline'],
                  'message': messageController.text.trim(),
                  'status': '대기중',
                  'timestamp': Timestamp.now(),
                  'likes': [],
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('신청을 보냈습니다!')),
                );
              },
              child: const Text('보내기'),
            ),
          ],
        );
      },
    );
  }

  Future<String> createDynamicLink(String postId) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://pottopia.page.link',
      link: Uri.parse('https://pottopia.com/post?postId=$postId'),
      androidParameters: const AndroidParameters(
        packageName: 'com.example.pottopia',
        minimumVersion: 1,
      ),
    );
    final shortLink =
        await FirebaseDynamicLinks.instance.buildShortLink(parameters);
    return shortLink.shortUrl.toString();
  }

  void _sharePost() async {
    if (post == null) return;
    final dynamicLink = await createDynamicLink(widget.postId);

    final shareText = '''
[${post!['title'] ?? '모임'}]

${post!['content'] ?? ''}

👇 자세히 보기
$dynamicLink
''';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    if (post == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<dynamic> images =
        widget.postData['imageUrls'] ?? ['assets/none1.jpg'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('게시물', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _sharePost,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) async {
              if (value == 'delete') {
                final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
                final ownerUid = widget.postData['ownerId'];

                // 작성자인지 확인
                if (currentUserUid != ownerUid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제 권한이 없습니다.')),
                  );
                  return;
                }

                // 삭제 확인
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('게시물 삭제'),
                    content: const Text('정말 이 게시물을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .delete();

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('게시물이 삭제되었습니다.')),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) {
              final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
              final isOwner = currentUserUid == widget.postData['ownerId'];

              return [
                if (isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제하기'),
                  ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.width,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final imagePath = images[index].toString();
                          if (imagePath.startsWith('http')) {
                            return Image.network(imagePath, fit: BoxFit.cover);
                          } else if (imagePath.startsWith('assets/')) {
                            return Image.asset(imagePath, fit: BoxFit.cover);
                          } else {
                            return Image.file(File(imagePath),
                                fit: BoxFit.cover);
                          }
                        },
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 8,
                      child: SmoothPageIndicator(
                        controller: _pageController,
                        count: images.length,
                        effect: WormEffect(
                          dotHeight: 6,
                          dotWidth: 6,
                          activeDotColor: Color(0xFF7F71FC),
                          dotColor: Colors.white54,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(
                  height: 1,
                  color: Color.fromARGB(255, 171, 162, 212),
                  thickness: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFF775DF8), size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.postData['location'] ?? '위치 미제공',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.postData['title'] ?? '',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                '작성자: ${widget.postData['ownerName'] ?? '알 수 없음'}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .where('postId', isEqualTo: widget.postData['postId'])
                    .where('status', isEqualTo: '수락함')
                    .snapshots(),
                builder: (context, snapshot) {
                  final currentCount = snapshot.data?.docs.length ?? 0;
                  final maxCount = widget.postData['headcount'] ?? 0;

                  return Text(
                    '인원 ($currentCount/$maxCount)',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                widget.postData['content'] ?? '',
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 5, // 필요에 따라 조정
              ),
              const SizedBox(height: 20),
              if (post!['tags'] != null && post!['tags'] is List) ...[
                Wrap(
                  spacing: 6,
                  children: (post!['tags'] as List).map<Widget>((tag) {
                    return Chip(
                      label: Text('#$tag'),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                      settings: RouteSettings(
                          arguments: widget.postData['ownerName']),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFEAE8FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            AssetImage('assets/profile_picture.png'),
                        backgroundColor: Colors.transparent, // 배경 없애고 이미지만
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.postData['ownerName'] ?? '알 수 없음',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: const [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                '4.6 · 후기 6',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser!;
                final postId = widget.postId;
                final postTitle = widget.postData['title'] ?? '게시물';
                final chatId = postId; // 게시물 기반으로 고정된 chatId
                final chatRef =
                    FirebaseFirestore.instance.collection('chats').doc(chatId);
                final chatDoc = await chatRef.get();

                final isOwner = currentUser.uid == widget.postData['ownerId'];

                // ✅ 1. 작성자는 무조건 채팅방 입장 가능
                bool isAccepted = false;

                if (!isOwner) {
                  // 작성자가 아닌 경우만 수락된 참여자인지 확인
                  final requestSnapshot = await FirebaseFirestore.instance
                      .collection('requests')
                      .where('postId', isEqualTo: postId)
                      .where('requesterId', isEqualTo: currentUser.uid)
                      .where('status', isEqualTo: '수락함')
                      .get();

                  isAccepted = requestSnapshot.docs.isNotEmpty;
                }

                if (!isOwner && !isAccepted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('채팅방은 참여 수락된 사용자만 입장할 수 있습니다.')),
                  );
                  return;
                }

                // 2. 채팅방이 없다면 새로 생성
                if (!chatDoc.exists) {
                  await chatRef.set({
                    'chatName': postTitle,
                    'postTitle': postTitle,
                    'isGroup': true,
                    'members': [currentUser.uid],
                    'timestamp': FieldValue.serverTimestamp(),
                    'lastMessage': '',
                    'lastReadTimestamps': {
                      currentUser.uid: Timestamp(0, 0),
                    },
                  });
                } else {
                  // 3. 기존 방이면 멤버에 현재 유저 추가
                  await chatRef.update({
                    'members': FieldValue.arrayUnion([currentUser.uid]),
                    'lastReadTimestamps.${currentUser.uid}': Timestamp(0, 0),
                  });
                }

                // 4. 채팅방으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomScreen(
                      chatId: chatId,
                      chatName: postTitle,
                      isGroup: true,
                      postId: postId,
                      postTitle: postTitle,
                      postOwnerUid: widget.postData['ownerId'],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _showRequestDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF775DF8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  '신청보내기',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            IconButton(
              icon: Image.asset(
                isLiked ? 'assets/hheart.png' : 'assets/love.png',
                width: 24,
                height: 24,
              ),
              onPressed: () async {
                final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
                final postRef = FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId);

                if (isLiked) {
                  await postRef.update({
                    'likes': FieldValue.arrayRemove([currentUserUid])
                  });
                } else {
                  await postRef.update({
                    'likes': FieldValue.arrayUnion([currentUserUid])
                  });
                }

                setState(() {
                  isLiked = !isLiked;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

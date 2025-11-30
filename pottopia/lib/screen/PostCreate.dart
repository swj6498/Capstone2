import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'Post.dart';
import 'Mapscreen.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  bool isOnline = true;
  String? address;
  double? lat;
  double? lng;

  final List<String> mainCategories = ['스터디팟', '운동팟', '공구팟', '취미팟'];
  final List<String> subCategories = ['배달비(해외배송)', '분철', '대량 물품 공구'];
  String selectedMainCategory = '운동팟';
  String? selectedSubCategory;

  final picker = ImagePicker();
  List<XFile> imageFiles = [];

  DateTimeRange selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 7)),
  );

  // Firebase Storage에 이미지 업로드하는 함수
  Future<String> uploadImageToFirebase(XFile imageFile) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child(
          'post_images/$fileName.jpg',
        );
    final uploadTask = ref.putFile(File(imageFile.path));
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final TextEditingController headcountController = TextEditingController();
  final TextEditingController tagController = TextEditingController();
  final List<String> tags = [];

  Future<void> pickImages() async {
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles.addAll(picked);
      });
    }
  }

  Future<void> selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDateRange: selectedDateRange,
    );
    if (picked != null) {
      setState(() => selectedDateRange = picked);
    }
  }

  void handleTagInput(String value) {
    if (value.endsWith(' ')) {
      final tag = value.trim();
      if (tag.isNotEmpty && !tags.contains(tag)) {
        setState(() {
          tags.add(tag);
          tagController.clear();
        });
      } else {
        tagController.clear();
      }
    }
  }

  Future<void> createPost() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userName = userDoc.data()?['nickname'] ?? '알 수 없음';

      List<String> imageUrls = [];
      if (imageFiles.isNotEmpty) {
        for (var image in imageFiles) {
          final url = await uploadImageToFirebase(image);
          imageUrls.add(url);
        }
      } else {
        imageUrls.add('assets/none1.jpg');
      }

      final docRef = await FirebaseFirestore.instance.collection('posts').add({
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
        'category': selectedMainCategory,
        'subCategory': selectedMainCategory == '공구팟' ? selectedSubCategory : '',
        'createdAt': Timestamp.now(),
        'headcount': int.tryParse(headcountController.text) ?? 0,
        'isOnline': isOnline,
        'location': isOnline ? '온라인' : (address ?? ''),
        if (!isOnline && lat != null && lng != null)
          'geo': GeoPoint(lat!, lng!),
        'tags': tags,
        'ownerId': user.uid,
        'ownerName': userName,
        'imageUrls': imageUrls,
        'likes': [], // ✅ 좋아요 초기화!
      });

      final postSnapshot = await docRef.get();
      final postData = postSnapshot.data()!;
      final postId = docRef.id;

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시물이 등록되었습니다!')));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostScreen(
              postData: {...postData, 'postId': postId},
              postId: postId,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('게시물 등록 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('게시물 작성', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Image.asset('assets/home2.png', width: 24, height: 24),
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: mainCategories.map((category) {
                  final isSelected = selectedMainCategory == category;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedMainCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color.fromARGB(255, 85, 85, 85) // 선택 시 배경
                            : Colors.grey[200], // 미선택 시 배경
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 15,
                          color: isSelected
                              ? Colors.white
                              : const Color.fromARGB(
                                  255, 57, 57, 57), // 서브카테고리와 동일
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (selectedMainCategory == '공구팟')
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: subCategories.map((sub) {
                    final selected = selectedSubCategory == sub;
                    return ChoiceChip(
                      label: Text(
                        sub,
                        style: const TextStyle(fontSize: 15),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => selectedSubCategory = sub);
                      },
                      showCheckmark: false,
                      selectedColor: const Color.fromARGB(211, 119, 93, 248),
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color.fromARGB(255, 62, 62, 62),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: selected
                              ? Colors.transparent
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: pickImages,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: imageFiles.map((file) {
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(file.path),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => imageFiles.remove(file)),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF775DF8)),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<bool>(
                    value: isOnline,
                    // ✅ 펼쳐지는 드롭다운 리스트의 border 둥글게
                    borderRadius: BorderRadius.circular(12),

                    // ✅ 선택된 값이 항상 맨 위에 오도록 동적 리스트 생성
                    items: [
                      DropdownMenuItem(
                        value: isOnline,
                        child: Text(isOnline ? '온라인' : '오프라인'),
                      ),
                      DropdownMenuItem(
                        value: !isOnline,
                        child: Text(!isOnline ? '온라인' : '오프라인'),
                      ),
                    ],

                    onChanged: (value) {
                      if (value != null) {
                        setState(() => isOnline = value);
                      }
                    },
                    style: const TextStyle(color: Colors.black),
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (!isOnline)
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MapScreen()),
                  );
                  if (result != null) {
                    setState(() {
                      address = result['address']; // 지도에서 반환된 주소 저장
                      lat = result['lat']; // 위도
                      lng = result['lng']; // 경도
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    address ?? '주소 입력 (지도 연동)',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: address == null ? Colors.grey : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF775DF8)),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: selectDateRange,
                  child: Text(
                    '${DateFormat('yyyy.MM.dd').format(selectedDateRange.start)} ~ ${DateFormat('yyyy.MM.dd').format(selectedDateRange.end)}',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF775DF8)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: headcountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '인원/수량'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: '제목을 입력해주세요',
                border: UnderlineInputBorder(),
              ),
              style: TextStyle(overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 12),
            Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextFormField(
                  controller: contentController,
                  keyboardType: TextInputType.multiline,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: '설명을 입력해주세요(2000자 이내)',
                    border: InputBorder.none,
                  ),
                )),
            const SizedBox(height: 12),
            TextField(
              controller: tagController,
              onChanged: handleTagInput,
              decoration: const InputDecoration(
                hintText: '# 해시태그 입력',
                border: InputBorder.none,
              ),
            ),
            Wrap(
              spacing: 8,
              children: tags
                  .map(
                    (tag) => Chip(
                      label: Text('# $tag'),
                      backgroundColor: Colors.grey.shade200, // ✅ 배경 연회색
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () {
                        setState(() {
                          tags.remove(tag);
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await createPost(); // Firestore에 데이터 저장
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF775DF8),
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '작성하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ); // close SafeArea and SingleChildScrollView
  }
}

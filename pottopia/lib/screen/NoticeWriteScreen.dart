import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoticeWriteScreen extends StatefulWidget {
  const NoticeWriteScreen({super.key});

  @override
  State<NoticeWriteScreen> createState() => _NoticeWriteScreenState();
}

class _NoticeWriteScreenState extends State<NoticeWriteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _submitNotice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final isAdmin = userDoc.exists && userDoc.data()?['isAdmin'] == true;

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공지사항 작성 권한이 없습니다.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('notices').add({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'author': user.email,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지사항이 등록되었습니다.')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항 작성'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,  // 전체 배경을 흰색으로 설정
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (value) => value == null || value.isEmpty ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '내용'),
                maxLines: 10,
                validator: (value) => value == null || value.isEmpty ? '내용을 입력하세요' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A6CFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('등록', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

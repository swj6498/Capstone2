import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String author;
  final DateTime createdAt;

  const NoticeDetailScreen({
    super.key,
    required this.title,
    required this.content,
    required this.author,
    required this.createdAt,
  });

  static Route routeFromData(Map<String, dynamic> data) {
    return MaterialPageRoute(
      builder: (_) => NoticeDetailScreen(
        title: data['title'],
        content: data['content'],
        author: data['author'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('공지사항', style: TextStyle(color: Colors.black)),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '작성자: $author · ${createdAt.year}.${createdAt.month}.${createdAt.day}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 32, thickness: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

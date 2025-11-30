import 'package:flutter/material.dart';

Future<void> showDeleteConfirmDialog(
  BuildContext context,
  VoidCallback onConfirm,
) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        actionsPadding: const EdgeInsets.only(
          bottom: 8,
          right: 5,
          left: 5,
        ), // ✅ 여백 조절
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        title: const Align(
          alignment: Alignment.center,
          child: Text(
            "정말 탈퇴하실 건가요 ㅠㅠ?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(221, 73, 73, 73),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("아니오"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7F71FC),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("네"),
          ),
        ],
      );
    },
  );
}

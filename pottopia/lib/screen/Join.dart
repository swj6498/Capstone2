import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Login.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  String selectedGender = '';
  String enteredCode = '';
  String _verificationState = ''; // '', 'success', 'failed'

  final TextEditingController nameController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  Future<void> sendVerificationCode() async {
    final email = emailController.text.trim();
    final generatedCode =
    (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

    try {
      await FirebaseFirestore.instance.collection('emailCodes').doc(email).set({
        'code': generatedCode,
        'createdAt': Timestamp.now(),
      });

      print('✅ 인증 코드: $generatedCode');
      setState(() => _verificationState = 'code_sent');

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('인증 코드가 발송되었습니다. (테스트용: $generatedCode)'),
      ));
    } catch (e) {
      print('❌ 코드 전송 실패: $e');
    }
  }

  Future<void> verifyCode() async {
    final email = emailController.text.trim();
    final inputCode = enteredCode.trim();

    final snapshot = await FirebaseFirestore.instance
        .collection('emailCodes')
        .doc(email)
        .get();

    if (snapshot.exists && snapshot.data()!['code'] == inputCode) {
      setState(() => _verificationState = 'success');
    } else {
      setState(() => _verificationState = 'failed');
    }
  }

  Future<void> registerUser() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("비밀번호가 일치하지 않습니다.")),
      );
      return;
    }

    if (_verificationState != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("이메일 인증을 완료해주세요.")),
      );
      return;
    }

    try {
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'nickname': nicknameController.text.trim(),
        'email': emailController.text.trim(),
        'gender': selectedGender,
        'createdAt': Timestamp.now(),
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('회원가입 완료'),
          content: const Text('회원가입이 성공적으로 완료되었습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("회원가입 실패: \${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Color(0xFF8A6CFF)),
        centerTitle: true,
        title: const Text(
          '회원가입',
          style:
          TextStyle(color: Color(0xFF8A6CFF), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabeledField('이름', nameController),
            const Text('성별', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGenderButton('남성'),
                const SizedBox(width: 12),
                _buildGenderButton('여성'),
              ],
            ),
            const SizedBox(height: 12),
            _buildLabeledField('닉네임', nicknameController),
            _buildLabeledField('아이디 (이메일)', emailController),

            const Text('이메일 인증', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      onChanged: (value) {
                        enteredCode = value;
                      },
                      decoration: InputDecoration(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: '인증번호 입력',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A6CFF),
                    minimumSize: const Size(70, 48),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('확인',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: sendVerificationCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A6CFF),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('인증 코드 보내기',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            if (_verificationState == 'success')
              const Text('인증이 완료되었습니다.', style: TextStyle(color: Colors.green))
            else if (_verificationState == 'failed')
              const Text('인증에 실패했습니다.', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 24),

            _buildLabeledField('비밀번호', passwordController, obscure: true),
            _buildLabeledField('비밀번호 확인', confirmPasswordController,
                obscure: true),

            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A6CFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('회원가입',
                    style: TextStyle(fontSize: 17, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGenderButton(String gender) {
    final bool isSelected = selectedGender == gender;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF8A6CFF) : Colors.white,
          side: BorderSide(
              color: isSelected ? const Color(0xFF8A6CFF) : Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() => selectedGender = gender);
        },
        child: Text(
          gender,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool loading = false;

  @override
  void initState() {
    super.initState();

    // Lắng nghe khi đăng nhập OTP thành công
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
        await _insertUserIfNeeded();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    });
  }

  Future<void> _insertUserIfNeeded() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final existing =
        await supabase.from('users').select().eq('id', user.id).maybeSingle();

    if (existing == null) {
      await supabase.from('users').insert({'id': user.id, 'email': user.email});
    }
  }

  Future<void> _signInWithEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => loading = true);

    try {
      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'io.supabase.flutter://login-callback',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check email để xác nhận đăng nhập')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đăng nhập thất bại: $e')));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Nhập email để đăng nhập / đăng ký',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _signInWithEmail,
              child:
                  loading
                      ? const CircularProgressIndicator()
                      : const Text('Gửi OTP đến email'),
            ),
          ],
        ),
      ),
    );
  }
}

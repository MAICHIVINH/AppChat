import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  final avatarController = TextEditingController();
  final genderController = TextEditingController();
  final addressController = TextEditingController();
  final bioController = TextEditingController();

  DateTime? selectedBirthDate;
  String? email;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        email = 'Không tìm thấy người dùng';
        loading = false;
      });
      return;
    }

    final response =
        await supabase.from('users').select().eq('id', user.id).maybeSingle();

    setState(() {
      email = user.email;
      nameController.text = response?['name'] ?? '';
      avatarController.text = response?['avatar'] ?? '';
      genderController.text = response?['gender'] ?? '';
      addressController.text = response?['address'] ?? '';
      bioController.text = response?['bio'] ?? '';
      final birthStr = response?['birthdate'];
      selectedBirthDate = birthStr != null ? DateTime.tryParse(birthStr) : null;
      loading = false;
    });
  }

  Future<void> _saveChanges() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('users')
        .update({
          'name': nameController.text.trim(),
          'avatar': avatarController.text.trim(),
          'gender': genderController.text.trim(),
          'address': addressController.text.trim(),
          'bio': bioController.text.trim(),
          'birthdate': selectedBirthDate?.toIso8601String(),
        })
        .eq('id', userId);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));

    setState(() {});
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final uploadedUrl = await uploadToCloudinary(file);

      if (uploadedUrl != null) {
        setState(() {
          avatarController.text = uploadedUrl;
        });

        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase
              .from('users')
              .update({'avatar': uploadedUrl})
              .eq('id', userId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tải ảnh thất bại')));
      }
    }
  }

  Future<String?> uploadToCloudinary(File file) async {
    const cloudName = 'YOUR_CLOUD_NAME';
    const uploadPreset = 'YOUR_UNSIGNED_PRESET';
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request =
        http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['secure_url'];
    } else {
      print('Upload error: ${res.body}');
      return null;
    }
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedBirthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: CircleAvatar(
              radius: 50,
              backgroundImage:
                  avatarController.text.isNotEmpty
                      ? NetworkImage(avatarController.text)
                      : null,
              child:
                  avatarController.text.isEmpty
                      ? const Icon(Icons.person, size: 50)
                      : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '(Nhấn vào ảnh để thay đổi)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(email ?? '', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 30),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: genderController,
            decoration: const InputDecoration(
              labelText: 'Giới tính',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickBirthdate,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Ngày sinh',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(
                  text:
                      selectedBirthDate != null
                          ? '${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}'
                          : '',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Tiểu sử (bio)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Lưu thay đổi'),
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            onPressed: _signOut,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

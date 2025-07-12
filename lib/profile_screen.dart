import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

    await supabase.from('users').update({
      'name': nameController.text.trim(),
      'avatar': avatarController.text.trim(),
      'gender': genderController.text.trim(),
      'address': addressController.text.trim(),
      'bio': bioController.text.trim(),
      'birthdate': selectedBirthDate?.toIso8601String(),
    }).eq('id', userId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công')),
      );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh thất bại')),
        );
      }
    }
  }

  Future<String?> uploadToCloudinary(File file) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null || uploadPreset == null) {
      print('Thiếu biến môi trường Cloudinary');
      return null;
    }

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url)
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (avatarController.text.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImage(
                                imageUrl: avatarController.text),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.teal.withOpacity(0.2),
                      backgroundImage: avatarController.text.isNotEmpty
                          ? NetworkImage(avatarController.text)
                          : null,
                      child: avatarController.text.isEmpty
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(Icons.edit, color: Colors.teal),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            _buildSectionTitle("Thông tin cá nhân"),
            const SizedBox(height: 12),
            _buildTextField("Tên hiển thị", nameController),
            const SizedBox(height: 12),
            _buildTextField("Giới tính", genderController),
            const SizedBox(height: 12),
            _buildTextField("Địa chỉ", addressController),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickBirthdate,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: _inputDecoration("Ngày sinh"),
                  controller: TextEditingController(
                    text: selectedBirthDate != null
                        ? "${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}"
                        : '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField("Tiểu sử (bio)", bioController, maxLines: 3),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Lưu thay đổi'),
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: Image.network(imageUrl)),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

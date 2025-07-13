// edit_profile_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  final avatarController = TextEditingController();
  final genderController = TextEditingController();
  final addressController = TextEditingController();
  final bioController = TextEditingController();
  DateTime? selectedBirthDate;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response =
        await supabase.from('users').select().eq('id', user.id).maybeSingle();

    setState(() {
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
      Navigator.pop(context); // quay lại trang trước
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

    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

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
        title: const Text('Chỉnh sửa thông tin'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: avatarController.text.isNotEmpty
                    ? NetworkImage(avatarController.text)
                    : null,
                backgroundColor: Colors.teal.withOpacity(0.2),
                child: avatarController.text.isEmpty
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField("Tên", nameController),
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
            _buildTextField("Tiểu sử", bioController, maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text("Lưu thay đổi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
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

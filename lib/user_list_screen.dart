import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';

class UserListScreen extends StatefulWidget {
  final void Function(String receiverId)? onUserSelected;

  const UserListScreen({super.key, this.onUserSelected});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final supabase = Supabase.instance.client;
  String? currentUserId;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUserId = supabase.auth.currentUser?.id;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final response = await supabase.from('users').select();
    final allUsers = List<Map<String, dynamic>>.from(response);

    setState(() {
      users = allUsers.where((user) => user['id'] != currentUserId).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat friends"),
        backgroundColor: Colors.teal,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
              ? const Center(child: Text('Chưa có người dùng nào để hiển thị'))
              : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading:
                        user['avatar'] != null &&
                                user['avatar'].toString().isNotEmpty
                            ? CircleAvatar(
                              backgroundImage: NetworkImage(user['avatar']),
                            )
                            : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user['name'] ?? 'Không tên'),
                    subtitle: Text(user['email'] ?? ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(receiverId: user['id']),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

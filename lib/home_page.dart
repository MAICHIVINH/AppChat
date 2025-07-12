import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  final void Function(int index) onNavigate; // Callback để điều hướng tab

  const HomePage({super.key, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  String? avatarUrl;
  String? userName;

  List<Map<String, dynamic>> recentChats = [];
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadRecentChats();
  }

  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final res = await supabase
          .from('users')
          .select('name, avatar')
          .eq('id', user.id)
          .single();

      setState(() {
        avatarUrl = res['avatar'];
        userName = res['name'] ?? 'Không tên';
      });
    }
  }

  Future<void> _loadRecentChats() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final messages = await supabase
        .from('messages')
        .select('id, content, sender_id, receiver_id, created_at')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(30);

    final Map<String, Map<String, dynamic>> uniqueConversations = {};

    for (final msg in messages) {
      final otherUserId =
          msg['sender_id'] == userId ? msg['receiver_id'] : msg['sender_id'];

      if (!uniqueConversations.containsKey(otherUserId)) {
        uniqueConversations[otherUserId] = msg;
      }
    }

    final recent = uniqueConversations.values.toList();

    final otherUserIds = recent.map(
      (msg) =>
          msg['sender_id'] == userId ? msg['receiver_id'] : msg['sender_id'],
    );

    final usersInfo = await supabase
        .from('users')
        .select('id, name, avatar')
        .inFilter('id', otherUserIds.toList());

    final userMap = {for (var u in usersInfo) u['id']: u};

    setState(() {
      recentChats = recent.map((msg) {
        final otherId =
            msg['sender_id'] == userId ? msg['receiver_id'] : msg['sender_id'];
        return {
          'user': userMap[otherId],
          'lastMessage': msg['content'],
          'created_at': msg['created_at'],
        };
      }).toList();
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    final currentUserId = supabase.auth.currentUser?.id;
    final res = await supabase
        .from('users')
        .select('id, name, avatar')
        .ilike('name', '%$query%')
        .neq('id', currentUserId!)
        .limit(10);

    setState(() {
      searchResults = res;
      isSearching = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm người dùng...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 32),
            if (isSearching && searchResults.isNotEmpty) ...[
              const Text(
                '🔎 Kết quả tìm kiếm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...searchResults.map((u) => _buildSearchResultTile(u)).toList(),
              const SizedBox(height: 24),
            ],
            if (recentChats.isNotEmpty) ...[
              const Text(
                '🕒 Cuộc trò chuyện gần đây',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...recentChats.map((chat) => _buildRecentChatCard(chat)).toList(),
            ],
            const SizedBox(height: 32),
            const Text(
              '📰 Tin tức mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildNewsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal, Colors.teal.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(avatarUrl!)
                    : null,
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? const Icon(Icons.person, size: 28, color: Colors.white)
                : null,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xin chào 👋',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  userName ?? 'Người dùng',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚀 Truy cập nhanh',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.chat_bubble_outline,
                title: 'Bắt đầu chat',
                color: Colors.blue,
                onTap: () {
                  widget.onNavigate(1); // Chuyển sang tab Chat
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.person_outline,
                title: 'Hồ sơ',
                color: Colors.orange,
                onTap: () {
                  widget.onNavigate(2); // Chuyển sang tab Cá nhân
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (user['avatar'] != null && user['avatar'].toString().isNotEmpty)
                  ? NetworkImage(user['avatar'])
                  : null,
          child: (user['avatar'] == null || user['avatar'].toString().isEmpty)
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(user['name'] ?? 'Không tên'),
        subtitle: const Text('Nhấn để bắt đầu chat'),
        onTap: () {
          // Xóa kết quả tìm kiếm trước khi chuyển trang
          setState(() {
            searchResults = [];
            isSearching = false;
            searchController.clear();
          });

          Navigator.pushNamed(context, '/chat', arguments: user['id']);
        },
      ),
    );
  }

  Widget _buildRecentChatCard(Map<String, dynamic> chat) {
    final user = chat['user'];
    final lastMessage = chat['lastMessage'] ?? '';
    final createdAt = chat['created_at'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (user['avatar'] != null && user['avatar'].toString().isNotEmpty)
                  ? NetworkImage(user['avatar'])
                  : null,
          child: (user['avatar'] == null || user['avatar'].toString().isEmpty)
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(user['name'] ?? 'Không tên'),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.pushNamed(context, '/chat', arguments: user['id']);
        },
      ),
    );
  }

  Widget _buildNewsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '🎉 Chúng tôi vừa thêm tính năng gửi video và ảnh! Hãy thử gửi ngay cho bạn bè nhé!',
        style: TextStyle(fontSize: 14),
      ),
    );
  }
}

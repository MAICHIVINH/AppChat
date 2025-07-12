import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;

  const ChatScreen({super.key, required this.receiverId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final controller = TextEditingController();
  final scrollController = ScrollController();

  String? userId;
  String? userEmail, userName, userAvatar;
  String? receiverEmail, receiverName, receiverAvatar;
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      userId = user.id;
      _fetchUserInfo().then((_) {
        _subscribeToMessages();
      });
    }
  }

  Future<void> _fetchUserInfo() async {
    final userRes =
        await supabase
            .from('users')
            .select('email, name, avatar')
            .eq('id', userId!)
            .single();

    final receiverRes =
        await supabase
            .from('users')
            .select('email, name, avatar')
            .eq('id', widget.receiverId)
            .single();

    setState(() {
      userEmail = userRes['email'];
      userName = userRes['name'];
      userAvatar = userRes['avatar'];

      receiverEmail = receiverRes['email'];
      receiverName = receiverRes['name'];
      receiverAvatar = receiverRes['avatar'];
    });
  }

  void _subscribeToMessages() {
    supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((data) {
          final filtered = data.where(
            (msg) =>
                (msg['sender_id'] == userId &&
                    msg['receiver_id'] == widget.receiverId) ||
                (msg['sender_id'] == widget.receiverId &&
                    msg['receiver_id'] == userId),
          );

          setState(() {
            messages = filtered.toList();
          });

          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        });
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || userId == null) return;

    await supabase.from('messages').insert({
      'sender_id': userId,
      'receiver_id': widget.receiverId,
      'content': text,
    });

    controller.clear();
    _scrollToBottom();
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    final picker = ImagePicker();
    final pickedFile =
        isVideo
            ? await picker.pickVideo(source: ImageSource.gallery)
            : await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && userId != null) {
      final url = await uploadToCloudinary(
        File(pickedFile.path),
        isVideo: isVideo,
      );
      if (url != null) {
        await supabase.from('messages').insert({
          'sender_id': userId,
          'receiver_id': widget.receiverId,
          'content': '',
          if (!isVideo) 'image_url': url,
          if (isVideo) 'video_url': url,
        });
      }
    }
  }

  Future<String?> uploadToCloudinary(File file, {required bool isVideo}) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null || uploadPreset == null) {
      print('Thiếu biến môi trường Cloudinary');
      return null;
    }

    final type = isVideo ? 'video' : 'image';
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/$type/upload',
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
      print('Upload failed: ${res.body}');
      return null;
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == userId;
    final createdAt =
        msg['created_at'] != null
            ? DateTime.parse(msg['created_at']).toLocal()
            : null;

    final senderName = isMe ? userName : receiverName;
    final senderAvatar = isMe ? userAvatar : receiverAvatar;

    final imageUrl = msg['image_url'];
    final videoUrl = msg['video_url'];
    final text = msg['content'] ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  senderAvatar != null && senderAvatar!.isNotEmpty
                      ? NetworkImage(senderAvatar!)
                      : null,
              child:
                  senderAvatar == null || senderAvatar!.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxWidth: 250),
          decoration: BoxDecoration(
            color: isMe ? Colors.teal[100] : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null)
                Text(
                  senderName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              if (imageUrl != null && imageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl),
                  ),
                ),
              if (videoUrl != null && videoUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(url: videoUrl),
                    ),
                  ),
                ),
              if (text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(text, style: const TextStyle(fontSize: 16)),
                ),
              if (createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
        if (isMe)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  userAvatar != null && userAvatar!.isNotEmpty
                      ? NetworkImage(userAvatar!)
                      : null,
              child:
                  userAvatar == null || userAvatar!.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(receiverName ?? receiverEmail ?? 'Đang tải...'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                messages.isEmpty
                    ? const Center(child: Text("Không có tin nhắn"))
                    : ListView.builder(
                      controller: scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(messages[index]);
                      },
                    ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.teal),
                  onPressed: () => _pickAndSendMedia(isVideo: false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.teal),
                  onPressed: () => _pickAndSendMedia(isVideo: true),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.teal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullScreenVideoPlayer(url: widget.url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _initialized
        ? GestureDetector(
          onTap: _openFullScreen,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              const Icon(Icons.fullscreen, color: Colors.white, size: 48),
            ],
          ),
        )
        : const Center(child: CircularProgressIndicator());
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String url;
  const FullScreenVideoPlayer({super.key, required this.url});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _initialized
              ? Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}

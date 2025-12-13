import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focusnflow/models/chat_message.dart';
import 'package:focusnflow/models/study_group.dart';
import 'package:focusnflow/services/chat_service.dart';

class GroupChatScreen extends StatefulWidget {
  final StudyGroup group;

  const GroupChatScreen({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    if (_currentUser == null) return;

    _chatService.sendMessage(
      groupId: widget.group.id,
      userId: _currentUser.uid,
      senderName: _currentUser.displayName ?? 'Anonymous',
      content: content,
    );

    _messageController.clear();
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.group.name),
            Text(
              '${widget.group.memberCount} members',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.streamGroupMessages(widget.group.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.userId == _currentUser?.uid;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: isCurrentUser
                              ? () => _showMessageOptions(context, message)
                              : null,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: isCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isCurrentUser)
                                  Text(
                                    message.senderName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  message.content,
                                  style: TextStyle(
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                if (message.isEdited) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'edited',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: isCurrentUser
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: isCurrentUser
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                ),
                                // Reactions
                                if (message.reactions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    children: message.reactions.entries.map((e) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[600],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${e.key} ${e.value}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction),
              title: const Text('Add Reaction'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context, message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChatMessage message) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _chatService.editMessage(
                groupId: widget.group.id,
                messageId: message.id,
                newContent: controller.text,
                userId: _currentUser!.uid,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _chatService.deleteMessage(
                groupId: widget.group.id,
                messageId: message.id,
                userId: _currentUser!.uid,
              );
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context, ChatMessage message) {
    const reactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('React with emoji'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: reactions.map((emoji) {
                return InkWell(
                  onTap: () {
                    _chatService.addReaction(
                      groupId: widget.group.id,
                      messageId: message.id,
                      emoji: emoji,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/study_group.dart';
import 'package:focusnflow/services/group_service.dart';
import 'package:focusnflow/screens/groups/group_chat_screen.dart' as chat;
import 'package:focusnflow/screens/groups/session_scheduling_screen.dart';
import 'package:focusnflow/screens/groups/pomodoro_screen.dart';

class StudyGroupsScreen extends StatefulWidget {
  const StudyGroupsScreen({Key? key}) : super(key: key);

  @override
  State<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends State<StudyGroupsScreen> {
  final _groupService = GroupService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late Stream<List<StudyGroup>> _userGroupsStream;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _userGroupsStream = _groupService.streamUserGroups(_currentUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Groups'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Groups'),
              Tab(text: 'Discover'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateGroupDialog(context),
              tooltip: 'Create Group',
            ),
          ],
        ),
        body: TabBarView(children: [_buildMyGroupsTab(), _buildDiscoverTab()]),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    if (_currentUser == null) {
      return const Center(child: Text('Please sign in to view your groups'));
    }

    return StreamBuilder<List<StudyGroup>>(
      stream: _userGroupsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No groups yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create or join a group to get started',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      DefaultTabController.of(context).animateTo(1),
                  icon: const Icon(Icons.search),
                  label: const Text('Discover Groups'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            return _buildGroupCard(context, groups[index], isMyGroup: true);
          },
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return _DiscoverGroupsWidget(
      groupService: _groupService,
      currentUserId: _currentUser?.uid ?? '',
      onGroupJoined: () {
        setState(() {
          // Refresh the my groups tab
        });
      },
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    StudyGroup group, {
    bool isMyGroup = false,
  }) {
    final isAdmin = group.adminId == _currentUser?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showGroupDetails(context, group),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          group.courseName,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    Chip(
                      label: const Text('Admin'),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                group.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text('${group.memberCount}/${group.maxMembers}'),
                    avatar: const Icon(Icons.people, size: 18),
                  ),
                  const SizedBox(height: 12),
                  if (isMyGroup)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openChat(context, group),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Chat'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openSessions(context, group),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Sessions'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openPomodoro(context, group),
                          icon: const Icon(Icons.timer, size: 18),
                          label: const Text('Timer'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _leaveGroup(context, group),
                          icon: const Icon(Icons.exit_to_app, size: 18),
                          label: const Text('Leave'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupDetails(BuildContext context, StudyGroup group) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _GroupDetailsSheet(
        group: group,
        groupService: _groupService,
        currentUserId: _currentUser?.uid ?? '',
        onGroupUpdated: () {
          setState(() {});
        },
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateGroupDialog(
        groupService: _groupService,
        currentUserId: _currentUser?.uid ?? '',
        onGroupCreated: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _leaveGroup(BuildContext context, StudyGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: Text('Are you sure you want to leave "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _groupService.leaveGroup(group.id, _currentUser!.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left group successfully')),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openChat(BuildContext context, StudyGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => chat.GroupChatScreen(group: group),
      ),
    );
  }

  void _openSessions(BuildContext context, StudyGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSchedulingScreen(group: group),
      ),
    );
  }

  void _openPomodoro(BuildContext context, StudyGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroScreen(group: group),
      ),
    );
  }
}

class _DiscoverGroupsWidget extends StatefulWidget {
  final GroupService groupService;
  final String currentUserId;
  final VoidCallback onGroupJoined;

  const _DiscoverGroupsWidget({
    required this.groupService,
    required this.currentUserId,
    required this.onGroupJoined,
  });

  @override
  State<_DiscoverGroupsWidget> createState() => _DiscoverGroupsWidgetState();
}

class _DiscoverGroupsWidgetState extends State<_DiscoverGroupsWidget> {
  final _searchController = TextEditingController();
  late Future<List<StudyGroup>> _allGroups;

  @override
  void initState() {
    super.initState();
    _allGroups = _fetchAllPublicGroups();
  }

  Future<List<StudyGroup>> _fetchAllPublicGroups() async {
    try {
      // For now, we'll fetch all groups (in production, add pagination)
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('isPublic', isEqualTo: true)
          .get();

      final groups = snapshot.docs
          .map((doc) => StudyGroup.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort in memory to avoid composite index requirement
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search groups...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<StudyGroup>>(
            future: _allGroups,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              var groups = snapshot.data ?? [];

              // Filter based on search
              if (_searchController.text.isNotEmpty) {
                groups = groups
                    .where(
                      (group) =>
                          group.name.toLowerCase().contains(
                            _searchController.text.toLowerCase(),
                          ) ||
                          group.courseName.toLowerCase().contains(
                            _searchController.text.toLowerCase(),
                          ),
                    )
                    .toList();
              }

              if (groups.isEmpty) {
                return const Center(child: Text('No groups found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _DiscoverGroupCard(
                    group: group,
                    groupService: widget.groupService,
                    currentUserId: widget.currentUserId,
                    onJoined: widget.onGroupJoined,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DiscoverGroupCard extends StatefulWidget {
  final StudyGroup group;
  final GroupService groupService;
  final String currentUserId;
  final VoidCallback onJoined;

  const _DiscoverGroupCard({
    required this.group,
    required this.groupService,
    required this.currentUserId,
    required this.onJoined,
  });

  @override
  State<_DiscoverGroupCard> createState() => _DiscoverGroupCardState();
}

class _DiscoverGroupCardState extends State<_DiscoverGroupCard> {
  bool _isJoining = false;
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _isMember = widget.group.memberIds.contains(widget.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.group.courseName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (widget.group.isFull)
                  Chip(
                    label: const Text('Full'),
                    backgroundColor: Colors.red.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.group.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    '${widget.group.memberCount}/${widget.group.maxMembers}',
                  ),
                  avatar: const Icon(Icons.people, size: 18),
                ),
                if (!_isMember)
                  ElevatedButton(
                    onPressed: _isJoining || widget.group.isFull
                        ? null
                        : _joinGroup,
                    child: _isJoining
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join'),
                  )
                else
                  Chip(
                    label: const Text('Member'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup() async {
    setState(() => _isJoining = true);

    try {
      await widget.groupService.joinGroup(
        widget.group.id,
        widget.currentUserId,
      );
      if (mounted) {
        setState(() => _isMember = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${widget.group.name}!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onJoined();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }
}

class _GroupDetailsSheet extends StatelessWidget {
  final StudyGroup group;
  final GroupService groupService;
  final String currentUserId;
  final VoidCallback onGroupUpdated;

  const _GroupDetailsSheet({
    required this.group,
    required this.groupService,
    required this.currentUserId,
    required this.onGroupUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: groupService.getGroupMembers(group.id),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            group.courseName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  group.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Members (${group.memberCount}/${group.maxMembers})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...members.map((member) {
                  return ListTile(
                    title: Text(member['displayName'] ?? 'Unknown'),
                    subtitle: Text(member['email'] ?? ''),
                    trailing: member['isAdmin']
                        ? Chip(label: const Text('Admin'))
                        : null,
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  final GroupService groupService;
  final String currentUserId;
  final VoidCallback onGroupCreated;

  const _CreateGroupDialog({
    required this.groupService,
    required this.currentUserId,
    required this.onGroupCreated,
  });

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseController = TextEditingController();
  bool _isPublic = true;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Study Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Data Structures Study Group',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _courseController,
              decoration: const InputDecoration(
                labelText: 'Course',
                hintText: 'e.g., CSC 3410',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What is this group about?',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Public Group'),
              value: _isPublic,
              onChanged: (value) {
                setState(() => _isPublic = value ?? true);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createGroup,
          child: _isCreating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty ||
        _courseController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      await widget.groupService.createGroup(
        name: _nameController.text,
        courseId: _courseController.text.replaceAll(' ', '_'),
        courseName: _courseController.text,
        description: _descriptionController.text,
        adminId: widget.currentUserId,
        isPublic: _isPublic,
      );

      if (mounted) {
        widget.onGroupCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "${_nameController.text}" created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _courseController.dispose();
    super.dispose();
  }
}

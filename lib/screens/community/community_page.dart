import 'package:flutter/material.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Map<String, String>> communities = [
    {"name": "Muradnagar", "desc": "Discuss problems here"},
    {"name": "Indirapuram", "desc": "Discuss problems here"},
    {"name": "Rajnagar", "desc": "Discuss problems here"},
    {"name": "Duhai", "desc": "Discuss problems here"},
  ];

  void _navigateToCreateCommunity() async {
    final newCommunity = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewCommunityScreen()),
    );

    if (newCommunity != null) {
      setState(() {
        communities.add(newCommunity);
      });
    }
  }

  void _navigateToChat(String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(groupName: groupName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("CivicCare Community"),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: communities.length,
        itemBuilder: (context, index) {
          final community = communities[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: primaryColor,
                child: const Icon(Icons.group, color: Colors.white),
              ),
              title: Text(
                community["name"]!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(community["desc"]!),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _navigateToChat(community["name"]!),
                child: const Text("Join",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: _navigateToCreateCommunity,
        child: const Icon(Icons.add),
        tooltip: "Create New Community",
      ),
    );
  }
}

/// ------------------- New Community Screen -------------------
class NewCommunityScreen extends StatefulWidget {
  const NewCommunityScreen({super.key});

  @override
  _NewCommunityScreenState createState() => _NewCommunityScreenState();
}

class _NewCommunityScreenState extends State<NewCommunityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(context, {
      "name": name,
      "desc": _descController.text.trim().isEmpty
          ? "Newly created community"
          : _descController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text("Create New Community")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Community Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
              onPressed: _submit,
              child: const Text(
                "Create Community",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// ------------------- Chat Screen -------------------
class ChatScreen extends StatefulWidget {
  final String groupName;
  const ChatScreen({super.key, required this.groupName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [
    {"sender": "Admin", "text": "Welcome to the group!"},
    {"sender": "User1", "text": "Streetlight near park is not working."},
    {"sender": "User2", "text": "Yes, I saw it too."},
  ];

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"sender": "You", "text": text});
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg["sender"] == "You";
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? primaryColor.withOpacity(0.3) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg["sender"]!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(msg["text"]!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: primaryColor),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

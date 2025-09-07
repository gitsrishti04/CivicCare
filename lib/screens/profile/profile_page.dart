import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;

  String name = '';
  String address = '';
  String phone = '';
  int tokens = 0;
  List<dynamic> issues = [];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(Uri.parse('https://your-backend.com/api/profile'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          name = data['name'] ?? '';
          address = data['address'] ?? '';
          phone = data['phone'] ?? '';
          tokens = data['tokens'] ?? 0;
          issues = data['issues'] ?? [];
          _nameController.text = name;
          _addressController.text = address;
          _phoneController.text = phone;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to backend'), backgroundColor: Colors.red),
      );
    }
    // Always show the fields, even if fetch fails
    setState(() {});
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final response = await http.post(
      Uri.parse('https://your-backend.com/api/profile/update'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
      }),
    );
    if (response.statusCode == 200) {
      setState(() {
        name = _nameController.text;
        address = _addressController.text;
        phone = _phoneController.text;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.red),
      );
    }
  }

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are logged out'), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditing)
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                      ),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        validator: (v) => v == null || v.isEmpty ? 'Enter address' : null,
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone No'),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.isEmpty ? 'Enter phone number' : null,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _updateProfile,
                        child: const Text('Save'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(name),
                  subtitle: const Text('Name'),
                ),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: Text(address),
                  subtitle: const Text('Address'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(phone),
                  subtitle: const Text('Phone No'),
                ),
                ListTile(
                  leading: const Icon(Icons.token),
                  title: Text(tokens.toString()),
                  subtitle: const Text('Tokens'),
                ),
                const SizedBox(height: 16),
                const Text('My Issues:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...issues.map((issue) => ListTile(
                      leading: const Icon(Icons.report_problem),
                      title: Text(issue['title'] ?? ''),
                      subtitle: Text(issue['status'] ?? ''),
                    )),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Edit your profile'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _logout,
                  child: const Text('Logout'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
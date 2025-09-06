import 'package:flutter/material.dart';

class MyComplaintHistoryPage extends StatelessWidget {
  const MyComplaintHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Complaint History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.person, color: Colors.blue, size: 20),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComplaintCard(
            id: '#CVC12345',
            department: 'Municipal Corporation',
            category: 'Waste Management',
            description: 'Garbage not collected from Area 9',
            date: '15 Aug, 11:50 AM',
            location: 'Area 9, Rajkot',
            status: 'Pending',
            statusColor: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildComplaintCard(
            id: '#CVC12569',
            department: 'Health & Family Welfare',
            category: 'Health & Family Welfare',
            description: '',
            date: '15 Aug, 11:28 AM',
            location: '',
            status: 'Resolved',
            statusColor: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildComplaintCard(
            id: '#CVC56569',
            department: 'Education Boards',
            category: 'Education, Employment & Training',
            description: '',
            date: '14 Aug, 09:42 AM',
            location: '',
            status: 'In Progress',
            statusColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildComplaintCard(
            id: '#CVC12869',
            department: 'Municipal Corporation',
            category: 'Waste Management',
            description: '',
            date: '13 Aug, 11:50 AM',
            location: '',
            status: 'Pending',
            statusColor: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildComplaintCard(
            id: '#CVC12469',
            department: 'Health & Family Welfare',
            category: 'Health & Family Welfare',
            description: '',
            date: '12 Aug, 03:25 AM',
            location: '',
            status: 'Resolved',
            statusColor: Colors.green,
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E40AF),
          unselectedItemColor: Colors.grey,
          currentIndex: 2, // My Complaints tab is selected
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              label: 'Departments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description),
              label: 'My Complaints',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard({
    required String id,
    required String department,
    required String category,
    required String description,
    required String date,
    required String location,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      department,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Sample usage in main.dart or your navigation
class ComplaintHistoryApp extends StatelessWidget {
  const ComplaintHistoryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Complaint History',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const MyComplaintHistoryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
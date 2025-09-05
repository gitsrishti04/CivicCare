import 'package:flutter/material.dart';
import 'package:civic_care/screens/complaint/complaint_register.dart'; // 🔹 Update with your package path

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1: // Complaints tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  RegisterComplaintScreen()),
        );
        break;
      // You can add navigation for other tabs here if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // Top AppBar with back button
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        title: const Text(
          "Govt. of India",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/login");
          },
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search + Location Row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Search department...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.location_on, color: Colors.red),
                  const Text("Amreli, Gujarat"),
                ],
              ),
            ),

            // Banner Image
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.blue[50],
                image: const DecorationImage(
                  image: AssetImage("assets/banner.png"),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 4 blocks (Grid)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBlock(Icons.add_circle, "Register Complaint"),
                  _buildBlock(Icons.track_changes, "Track Complaint"),
                  _buildBlock(Icons.history, "My Complaint History"),
                  _buildBlock(Icons.list_alt, "Department List"),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade800,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.report_problem), label: "Complaints"),
          BottomNavigationBarItem(icon: Icon(Icons.apartment), label: "Communities"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildBlock(IconData icon, String title) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.blue.shade800),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

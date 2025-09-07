import 'package:civic_care/screens/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:civic_care/screens/complaint/complaint_register.dart';
import 'package:civic_care/screens/complaint/track_complaint.dart';
import 'package:civic_care/screens/complaint/complaint_history.dart';
import 'package:civic_care/screens/community/community_page.dart';
import 'package:civic_care/screens/profile/profile_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:civic_care/constants/api_constants.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _locationText = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  // ...existing code...

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationText = "Location services disabled";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() {
            _locationText = "Location permission denied";
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationText =
              "${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
        });
      } else {
        setState(() {
          _locationText = "Location not found";
        });
      }
    } catch (e) {
      setState(() {
        _locationText = "Error fetching location";
      });
    }
  }

// ...existing code...
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1: // Complaints tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RegisterComplaintScreen()),
        );
        break;
      case 2: // Communities tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CommunityPage()),
        );
        break;
      case 3: // Profile tab
        Navigator.push(context, MaterialPageRoute(builder:(context) => ProfilePage(),));
      // Add navigation for other tabs if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // Top AppBar
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
                  Flexible(
                    child: Text(
                      _locationText,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
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
                  _buildBlock(
                    icon: Icons.add_circle,
                    title: "Register Complaint",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterComplaintScreen(),
                        ),
                      );
                    },
                  ),
                  _buildBlock(
                    icon: Icons.track_changes,
                    title: "Track Complaint",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackComplaintPage(),
                        ),
                      );
                    },
                  ),
                  _buildBlock(
                    icon: Icons.history,
                    title: "My Complaint History",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyComplaintHistoryPage(),
                        ),
                      );
                    },
                  ),
                  _buildBlock(
                    icon: Icons.list_alt,
                    title: "Department List",
                    onTap: () {
                      // Navigate to Department List Page
                    },
                  ),
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

  Widget _buildBlock({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

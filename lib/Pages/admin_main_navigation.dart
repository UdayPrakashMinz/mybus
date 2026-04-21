import 'package:flutter/material.dart';
import 'package:mybus/Pages/admin_dashboard.dart';
import 'manage_bus_page.dart';
import 'manage_trips_page.dart';
import 'profile_page.dart';

class AdminMainNavigation extends StatefulWidget {
  const AdminMainNavigation({super.key});

  @override
  State<AdminMainNavigation> createState() => _AdminMainNavigationState();
}

class _AdminMainNavigationState extends State<AdminMainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    AdminDashboardPage(),
    ManageBusPage(),
    ManageTripsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        selectedItemColor: const Color(0xFF00B4D8),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: "Buses",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: "Trips"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

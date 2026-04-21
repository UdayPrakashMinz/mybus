import 'package:flutter/material.dart';
import 'package:mybus/Pages/HomePage.dart';
import 'package:mybus/Pages/booking_history_page.dart';
import 'package:mybus/Pages/profile_page.dart';
import 'package:mybus/Pages/search_page.dart';

class HomeMainNavigation extends StatefulWidget {
  const HomeMainNavigation({super.key});

  @override
  State<HomeMainNavigation> createState() => _HomeMainNavigationState();
}

class _HomeMainNavigationState extends State<HomeMainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ConsumerHomePage(),
    SearchPage(),
    BookingHistoryPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "HOME"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "SEARCH"),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: "BOOKINGS",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "PROFILE"),
        ],
      ),
    );
  }
}

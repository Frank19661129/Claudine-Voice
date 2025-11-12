/// Claudine - Home Screen with 3-button navigation
/// Voice | Notes | Scan
/// Part of Claudine Suite by Franklab

import 'package:flutter/material.dart';
import '../main.dart';
import 'notes_list_screen.dart';
// import 'scan_camera_screen.dart'; // Temporarily disabled - fixing bugs

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Three main screens
  final List<Widget> _screens = [
    const VoiceScreen(),      // Existing voice screen
    const NotesListScreen(),  // New notes screen
    const Center(child: Text('Scan coming soon!')), // Scan temporarily disabled
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Voice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.scanner),
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}

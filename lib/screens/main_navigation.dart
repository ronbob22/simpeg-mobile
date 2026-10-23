import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'home_tab.dart';
import 'saldo_tab.dart';
import 'request_tab.dart';
import 'history_tab.dart';
import 'akun_tab.dart';

/// Kerangka navigasi bawah sesuai Gambar 3.5 di laporan:
/// Home, Saldo, Request, History, Akun.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final _tabs = const [
    HomeTab(),
    SaldoTab(),
    RequestTab(),
    HistoryTab(),
    AkunTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kSimpegPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card_outlined), label: 'Saldo'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Request'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Akun'),
        ],
      ),
    );
  }
}
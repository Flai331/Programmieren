import 'package:flutter/material.dart';
import 'screens.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const InvoiceListScreen(),
    const AddressBookScreen(),
    const ArticlesScreen(),
    const TemplatesScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  late final List<NavigationDestination> _destinations = [
    const NavigationDestination(
      icon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    const NavigationDestination(
      icon: Icon(Icons.receipt),
      label: 'Rechnungen',
    ),
    const NavigationDestination(
      icon: Icon(Icons.contacts),
      label: 'Kunden',
    ),
    const NavigationDestination(
      icon: Icon(Icons.shopping_bag),
      label: 'Artikel',
    ),
    const NavigationDestination(
      icon: Icon(Icons.design_services),
      label: 'Vorlagen',
    ),
    const NavigationDestination(
      icon: Icon(Icons.bar_chart),
      label: 'Stats',
    ),
    const NavigationDestination(
      icon: Icon(Icons.settings),
      label: 'Einstellungen',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../utils/feedback_service.dart';
import 'screens.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const Color _peach = Color(0xFFfda085);
  static const Color _gold  = Color(0xFFf6d365);

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const InvoiceListScreen(),
    const AddressBookScreen(),
    const ArticlesScreen(),
    const TemplatesScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  late final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_outlined),
      selectedIcon: Icon(Icons.receipt),
      label: 'Rechnungen',
    ),
    NavigationDestination(
      icon: Icon(Icons.contacts_outlined),
      selectedIcon: Icon(Icons.contacts),
      label: 'Kunden',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_bag_outlined),
      selectedIcon: Icon(Icons.shopping_bag),
      label: 'Artikel',
    ),
    NavigationDestination(
      icon: Icon(Icons.design_services_outlined),
      selectedIcon: Icon(Icons.design_services),
      label: 'Vorlagen',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Stats',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Einstellungen',
    ),
  ];

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('MainNavigation');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: _peach.withAlpha(40),
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
          FeedbackService.logUserAction('Tab gewechselt',
              context: {'tab': index.toString()});
        },
        destinations: _destinations,
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gold, _peach],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _peach.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        onPressed: () {
          FeedbackService.logUserAction('Neue Rechnung erstellen (FAB)');
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const InvoiceEditScreen(),
          ));
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Neue Rechnung',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

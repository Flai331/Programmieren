import 'package:flutter/material.dart';
import '../fehlerbericht.dart';
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

  static const List<String> _titles = [
    'Dashboard',
    'Völker',
    'Rechnungen',
    'Kunden',
    'Artikel',
    'Vorlagen',
    'Briefe',
    'Statistiken',
    'Einstellungen',
  ];

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
    Fehlerbericht.logAktion('Tab gewechselt (Dashboard)',
        kontext: {'tab': index.toString()});
  }

  late final List<Widget> _screens = [
    DashboardScreen(onNavigate: _goToTab),
    const HiveListScreen(),
    const InvoiceListScreen(),
    const AddressBookScreen(),
    const ArticlesScreen(),
    const TemplatesScreen(),
    const LetterListScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  late final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Start',
    ),
    NavigationDestination(
      icon: Icon(Icons.hive_outlined),
      selectedIcon: Icon(Icons.hive),
      label: 'Völker',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_outlined),
      selectedIcon: Icon(Icons.receipt),
      label: 'Rechng.',
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
      icon: Icon(Icons.mail_outline),
      selectedIcon: Icon(Icons.mail),
      label: 'Briefe',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Stats',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Mehr',
    ),
  ];

  @override
  void initState() {
    super.initState();
    Fehlerbericht.logSeite('MainNavigation');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        
      ),
      body: _screens[_selectedIndex],
      // FAB nur auf Rechnungen-Tab (Index 2). Völker (Index 1) hat eigenen FAB.
      floatingActionButton: _selectedIndex == 2 ? _buildFab(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 10,
              height: 1.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Labels einzeilig halten
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          indicatorColor: _peach.withAlpha(51), // 20% per design system
          onDestinationSelected: (int index) {
            setState(() => _selectedIndex = index);
            Fehlerbericht.logSeite(_titles[index]);
            Fehlerbericht.logAktion('Tab gewechselt',
                kontext: {'tab': index.toString()});
          },
          destinations: _destinations,
        ),
      ),
    );
  }

  void _showCreateChooser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.receipt_outlined, color: _peach),
              title: const Text('Neue Rechnung'),
              onTap: () {
                Navigator.pop(ctx);
                Fehlerbericht.logAktion('Neue Rechnung (FAB)');
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InvoiceEditScreen(documentType: 'invoice'),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: _peach),
              title: const Text('Neues Angebot'),
              onTap: () {
                Navigator.pop(ctx);
                Fehlerbericht.logAktion('Neues Angebot (FAB)');
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InvoiceEditScreen(documentType: 'quote'),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline, color: _peach),
              title: const Text('Neuer Brief'),
              onTap: () {
                Navigator.pop(ctx);
                Fehlerbericht.logAktion('Neuer Brief (FAB)');
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LetterEditScreen(),
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
            color: _peach.withAlpha(89), // 35% per design system
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        onPressed: () => _showCreateChooser(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Neu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

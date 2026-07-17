import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../login/login_screen.dart';
import '../pos/pos_screen.dart';
import '../printer/printer_settings_screen.dart';
import '../sales/sales_list_screen.dart';
import '../draft/draft_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const routeName = '/main';

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _draftTabEpoch = 0;

  List<Widget> get _pages => [
        const PosScreen(),
        DraftListScreen(
          key: ValueKey('draft-$_draftTabEpoch'),
          onRestoreToPos: _goToPos,
        ),
        const SalesListScreen(),
      ];

  static const _titles = ['POS', 'Draft', 'Sales List'];

  void _goToPos() => setState(() => _index = 0);

  Future<void> _logout() async {
    await AppScope.of(context).auth.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      LoginScreen.routeName,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.textOnPrimary,
        title: Text('MPOS - ${_titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Bluetooth printer',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.print_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.18),
              child: IconButton(
                tooltip: 'Log out',
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: AppColors.textOnPrimary),
              ),
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: AppColors.background,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          _index = value;
          if (value == 1) _draftTabEpoch++;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.drafts_outlined),
            selectedIcon: Icon(Icons.drafts),
            label: 'Draft',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Sales List',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'suppliers_screen.dart';
import 'projects_screen.dart';
import 'invoices_screen.dart';
import 'invoice_form_screen.dart';
import 'supplier_form_screen.dart';
import 'project_form_screen.dart';
import 'settings_screen.dart';
import 'expense_report_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    InvoicesScreen(),
    const SuppliersScreen(),
    const ProjectsScreen(),
    const ExpenseReportFormScreen(),
  ];

  final List<String> _screenLabels = const [
    'Facturas',
    'Proveedores',
    'Proyectos',
    'Gastos',
  ];
  final List<IconData> _screenIcons = const [
    Icons.receipt_long,
    Icons.business,
    Icons.folder,
    Icons.money,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturas SSP'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: List.generate(
          _screens.length,
          (index) => NavigationDestination(
            icon: Icon(_screenIcons[index]),
            label: _screenLabels[index],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InvoiceFormScreen(),
              ),
            );
            setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('Nueva Factura'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupplierFormScreen(),
              ),
            );
            setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('Nuevo Proveedor'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProjectFormScreen(),
              ),
            );
            setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('Nuevo Proyecto'),
        );
      default:
        return null;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AuthService>().logout();
              Navigator.pop(context);
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}

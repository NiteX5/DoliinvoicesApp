import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dolibarr_service.dart';

/// Pantalla de configuración de la conexión a Dolibarr.
///
/// Permite definir la URL base de la API en tiempo de ejecución (se persiste
/// en SharedPreferences) sin necesidad de recompilar la app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final service = context.read<DolibarrService>();
    _baseUrlController = TextEditingController(text: service.baseUrl);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final service = context.read<DolibarrService>();
    final url = _baseUrlController.text.trim();

    await service.setBaseUrl(url);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL de Dolibarr guardada correctamente')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Conexión a Dolibarr ──────────────────────────────────────
              Text('Conexión a Dolibarr',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _baseUrlController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'URL base de la API',
                          hintText: 'https://tu-dominio.com/dolibarr/api/index.php',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Ingresa la URL base de Dolibarr';
                          }
                          if (!v.startsWith('http://') &&
                              !v.startsWith('https://')) {
                            return 'La URL debe comenzar con http:// o https://';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'La API Key se ingresa en la pantalla de login. '
                        'Si dejas esta URL vacía en la app, se usa la definida '
                        'con --dart-define en la compilación.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Acerca de ────────────────────────────────────────────────
              Text('Acerca de', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: colorScheme.primary),
                  title: const Text('Facturas SSP'),
                  subtitle: const Text(
                      'Gestión de facturas de proveedores con OCR/IA y Dolibarr'),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

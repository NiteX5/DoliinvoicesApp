import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../invoice_ai/invoice_ai_service.dart';
import '../models/project.dart';
import '../services/auth_service.dart';
import '../services/dolibarr_service.dart';

enum PriceSource { unitPrice, withVat }

class ExpenseReportFormScreen extends StatefulWidget {
  const ExpenseReportFormScreen({super.key});

  static const routeName = '/gastos';

  @override
  State<ExpenseReportFormScreen> createState() => _ExpenseReportFormScreenState();
}

class _ExpenseReportFormScreenState extends State<ExpenseReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _unitPriceWithVatController = TextEditingController();
  final _vatController = TextEditingController(text: '19');

  final List<_ExpenseLineDraft> _lines = [];
  List<Project> _projects = [];
  List<Map<String, dynamic>> _expenseTypes = [];
  Project? _selectedProject;
  int? _selectedExpenseTypeId;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isProcessingImage = false;
  bool _isSyncingPrices = false;
  PriceSource _priceSource = PriceSource.unitPrice;
  Map<String, dynamic>? get _selectedExpenseType =>
      _expenseTypeById(_selectedExpenseTypeId);

  @override
  void initState() {
    super.initState();
    _unitPriceController.addListener(_syncPriceWithVatFromUnitPrice);
    _unitPriceWithVatController.addListener(_syncUnitPriceFromPriceWithVat);
    _vatController.addListener(_syncPricesFromVat);
    _loadInitialData();
  }

  @override
  void dispose() {
    _refController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    _unitPriceWithVatController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();
    final apiKey = authService.apiKey;
    if (apiKey == null) return;

    try {
      final projectsData = await dolibarrService.getProjects(apiKey);
      final typesData = await dolibarrService.getExpenseTypes(apiKey);
      if (!mounted) return;
      setState(() {
        _projects = projectsData.map((json) => Project.fromJson(json)).toList();
        _expenseTypes = typesData;
        if (_expenseTypes.isNotEmpty) {
          _selectedExpenseTypeId = _expenseTypeId(_expenseTypes.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar proyectos o tipos: $e')),
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _parseDate(String value) {
    return DateTime.tryParse(value.trim()) ?? DateTime.now();
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
  }

  double _roundAmount(double value) => (value * 100).roundToDouble() / 100;

  String _formatAmount(double value) {
    final rounded = _roundAmount(value);
    if (rounded == rounded.truncateToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(2);
  }

  double _unitPriceWithVat(double unitPrice, double vatRate) {
    return _roundAmount(unitPrice * (1 + vatRate / 100));
  }

  double _unitPriceWithoutVat(double unitPriceWithVat, double vatRate) {
    if (vatRate <= 0) return unitPriceWithVat;
    return _roundAmount(unitPriceWithVat / (1 + vatRate / 100));
  }

  int? _expenseTypeId(Map<String, dynamic> type) {
    final value = type['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _expenseTypeById(int? id) {
    if (id == null) return null;
    for (final type in _expenseTypes) {
      if (_expenseTypeId(type) == id) return type;
    }
    return null;
  }

  void _syncPriceWithVatFromUnitPrice() {
    if (_isSyncingPrices) return;
    _priceSource = PriceSource.unitPrice;
    final unitPrice = _parseAmount(_unitPriceController.text);
    final vatRate = _parseAmount(_vatController.text);
    _setSyncedText(
      _unitPriceWithVatController,
      _formatAmount(_unitPriceWithVat(unitPrice, vatRate)),
    );
  }

  void _syncUnitPriceFromPriceWithVat() {
    if (_isSyncingPrices) return;
    _priceSource = PriceSource.withVat;
    final unitPriceWithVat = _parseAmount(_unitPriceWithVatController.text);
    final vatRate = _parseAmount(_vatController.text);
    _setSyncedText(
      _unitPriceController,
      _formatAmount(_unitPriceWithoutVat(unitPriceWithVat, vatRate)),
    );
  }

  void _syncPricesFromVat() {
    if (_isSyncingPrices) return;
    if (_priceSource == PriceSource.unitPrice) {
      final unitPrice = _parseAmount(_unitPriceController.text);
      final vatRate = _parseAmount(_vatController.text);
      _setSyncedText(
        _unitPriceWithVatController,
        _formatAmount(_unitPriceWithVat(unitPrice, vatRate)),
      );
    } else {
      final unitPriceWithVat = _parseAmount(_unitPriceWithVatController.text);
      final vatRate = _parseAmount(_vatController.text);
      _setSyncedText(
        _unitPriceController,
        _formatAmount(_unitPriceWithoutVat(unitPriceWithVat, vatRate)),
      );
    }
  }

  void _setSyncedText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    _isSyncingPrices = true;
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    _isSyncingPrices = false;
  }

  Future<void> _selectDate() async {
    final initialDate = DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateController.text = _formatDate(picked));
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar boleta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
    });
    await _processImageWithOcr();
  }

  Future<void> _processImageWithOcr() async {
    final image = _selectedImage;
    if (image == null) return;

    setState(() => _isProcessingImage = true);
    try {
      final invoiceAiService = context.read<InvoiceAiService>();
      final result = await invoiceAiService.processImage(image);
      if (!mounted) return;

      final detectedDate = result.date;
      final newLines = result.items.map((item) {
        final qty = item.qty.toDouble();
        final vatRate = item.tvaTx.toDouble();
        // Asegúrate de agregar la dependencia en pubspec.yaml

// Reemplazar cálculos de precio con BigDecimal:
final unitPrice = double.tryParse(item.subprice.replaceAll(',', '.')) ?? 0.0;
        final unitPriceWithVat = item.priceIncludesVat
            ? unitPrice
            : _roundAmount(unitPrice * (1 + vatRate / 100));
        return _ExpenseLineDraft(
          date: detectedDate != null ? _parseDate(detectedDate) : _parseDate(_dateController.text),
          project: _selectedProject,
          expenseType: _expenseTypeById(_selectedExpenseTypeId),
          description: item.description,
          vatRate: vatRate,
          unitPriceWithVat: unitPriceWithVat,
          qty: qty,
        );
      }).toList();

      setState(() {
        if (detectedDate != null && detectedDate.isNotEmpty) {
          _dateController.text = detectedDate;
        }
        _lines
          ..clear()
          ..addAll(newLines);
        _isProcessingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newLines.isEmpty
              ? 'OCR completado, pero no se detectaron productos. Puedes agregarlos manualmente.'
              : 'OCR completado: ${newLines.length} líneas detectadas.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingImage = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('No se pudo procesar la boleta'),
          content: Text('Error: ${e.toString()}. Por favor, inténtalo de nuevo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  void _addManualLine() {
    final description = _descriptionController.text.trim();
    final qty = _parseAmount(_qtyController.text);
    final unitPriceWithVat = _parseAmount(_unitPriceWithVatController.text);
    final vatRate = _parseAmount(_vatController.text);

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La descripción es obligatoria')),
      );
      return;
    }
    if (_selectedExpenseType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un tipo de gasto')),
      );
      return;
    }
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un proyecto')),
      );
      return;
    }
    if (qty <= 0 || unitPriceWithVat < 0 || vatRate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad, precio e IVA deben ser válidos')),
      );
      return;
    }

    setState(() {
      _lines.add(_ExpenseLineDraft(
        date: _parseDate(_dateController.text),
        project: _selectedProject,
        expenseType: _selectedExpenseType,
        description: description,
        vatRate: vatRate,
        unitPriceWithVat: unitPriceWithVat,
        qty: qty,
      ));
      _descriptionController.clear();
      _qtyController.text = '1';
      _unitPriceWithVatController.clear();
      _vatController.text = '19';
    });
  }

  void _applyProjectToAll(Project? project) {
    setState(() {
      _selectedProject = project;
      for (var i = 0; i < _lines.length; i++) {
        _lines[i] = _lines[i].copyWith(project: project);
      }
    });
  }

  void _applyTypeToAll(Map<String, dynamic>? type) {
    setState(() {
      _selectedExpenseTypeId = type == null ? null : _expenseTypeId(type);
      for (var i = 0; i < _lines.length; i++) {
        _lines[i] = _lines[i].copyWith(expenseType: type);
      }
    });
  }

  Future<void> _saveExpenseReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las líneas deben tener proyecto, tipo, descripción y cantidad válida')),
      );
      return;
    }

    final invalidLine = _lines.any((line) =>
        line.project?.id == null ||
        line.expenseType == null ||
        line.description.trim().isEmpty ||
        line.qty <= 0);
    if (invalidLine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las líneas deben tener proyecto, tipo, descripción y cantidad válida')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();
    final apiKey = authService.apiKey;
    if (apiKey == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userId = await dolibarrService.getCurrentUserId(apiKey);
      final documentDate = _parseDate(_dateController.text);
      final expenseReportId = await dolibarrService.createExpenseReport(
        apiKey: apiKey,
        userId: userId,
        invoiceDate: documentDate,
        ref: _refController.text,
      );

      for (final line in _lines) {
        await dolibarrService.addExpenseReportLine(
          expenseReportId: expenseReportId,
          apiKey: apiKey,
          date: line.date,
          typeFeeId: line.typeId!,
          description: line.description,
          qty: line.qty,
          valueUnit: line.unitPriceWithoutVat,
          vatRate: line.vatRate,
          projectId: line.project!.id,
        );
      }

      final image = _selectedImage;
      if (image != null) {
        await dolibarrService.attachExpenseReportImage(
          expenseReportId: expenseReportId,
          filePath: image.path,
          fileName: image.uri.pathSegments.isNotEmpty
              ? image.uri.pathSegments.last
              : 'boleta_gasto.jpg',
          apiKey: apiKey,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Centro de gasto $expenseReportId creado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('No se pudo crear el gasto'),
          content: SingleChildScrollView(child: Text(e.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildScanCard(),
            const SizedBox(height: 16),
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildDefaultsCard(),
            const SizedBox(height: 16),
            _buildManualLineCard(),
            const SizedBox(height: 16),
            _buildLinesCard(),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveExpenseReport,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isLoading ? 'Subiendo gasto...' : 'Subir gasto a Dolibarr'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escaneo de boleta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 44, color: Colors.grey[500]),
                    const SizedBox(height: 8),
                    Text('Sin boleta escaneada', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isProcessingImage ? null : _showImageSourceDialog,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Escanear boleta'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
            if (_isProcessingImage) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Procesando boleta con OCR...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de gasto',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refController,
              decoration: const InputDecoration(
                labelText: 'Referencia del centro de gasto (opcional)',
                prefixIcon: Icon(Icons.tag),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Fecha de emisión *',
                prefixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _selectDate,
                ),
              ),
              readOnly: true,
              onTap: _selectDate,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'La fecha es obligatoria'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valores por defecto para líneas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Project>(
              initialValue: _selectedProject,
              decoration: const InputDecoration(
                labelText: 'Proyecto *',
                prefixIcon: Icon(Icons.folder),
                border: OutlineInputBorder(),
              ),
              items: _projects
                  .map((project) => DropdownMenuItem(
                        value: project,
                        child: Text('${project.ref} - ${project.title}'),
                      ))
                  .toList(),
              onChanged: _applyProjectToAll,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedExpenseType,
              decoration: const InputDecoration(
                labelText: 'Tipo de gasto *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _expenseTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type['label']?.toString() ?? 'Sin nombre'),
                      ))
                  .toList(),
              onChanged: _applyTypeToAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualLineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar línea manual',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'P.U. *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceWithVatController,
                    decoration: const InputDecoration(
                      labelText: 'P.U. (i.i.) *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vatController,
                    decoration: const InputDecoration(
                      labelText: 'IVA %',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addManualLine,
              icon: const Icon(Icons.add),
              label: const Text('Agregar línea'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Líneas de gasto',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_lines.isEmpty)
              Text('No hay líneas agregadas todavía', style: TextStyle(color: Colors.grey[600]))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildLineTile(index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineTile(int index) {
    final line = _lines[index];
    final total = _roundAmount(line.qty * line.unitPriceWithVat);
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      title: Text(line.description),
      subtitle: Text(
        'Fecha: ${_formatDate(line.date)} | Proyecto: ${line.project?.ref ?? 'Sin proyecto'}\n'
        'Tipo: ${line.expenseType?['label'] ?? 'Sin tipo'} | IVA: ${line.vatRate}% | '
        'P.U.: ${line.unitPriceWithoutVat.toStringAsFixed(2)} | P.U. i.i.: ${line.unitPriceWithVat.toStringAsFixed(2)} | Cant.: ${line.qty}',
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            tooltip: 'Eliminar línea',
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => setState(() => _lines.removeAt(index)),
          ),
        ],
      ),
    );
  }
}

class _ExpenseLineDraft {
  final DateTime date;
  final Project? project;
  final Map<String, dynamic>? expenseType;
  final String description;
  final double vatRate;
  final double unitPriceWithVat;
  final double qty;

  const _ExpenseLineDraft({
    required this.date,
    required this.project,
    required this.expenseType,
    required this.description,
    required this.vatRate,
    required this.unitPriceWithVat,
    required this.qty,
  });

  int? get typeId {
    final value = expenseType?['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double get unitPriceWithoutVat {
    if (vatRate <= 0) return unitPriceWithVat;
    return ((unitPriceWithVat / (1 + vatRate / 100)) * 100).roundToDouble() / 100;
  }

  _ExpenseLineDraft copyWith({
    DateTime? date,
    Project? project,
    Map<String, dynamic>? expenseType,
    String? description,
    double? vatRate,
    double? unitPriceWithVat,
    double? qty,
  }) {
    return _ExpenseLineDraft(
      date: date ?? this.date,
      project: project ?? this.project,
      expenseType: expenseType ?? this.expenseType,
      description: description ?? this.description,
      vatRate: vatRate ?? this.vatRate,
      unitPriceWithVat: unitPriceWithVat ?? this.unitPriceWithVat,
      qty: qty ?? this.qty,
    );
  }
}

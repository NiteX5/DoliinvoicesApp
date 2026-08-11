import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/dolibarr_service.dart';
import '../invoice_ai/invoice_ai_service.dart';
import '../models/supplier_invoice.dart';
import '../models/supplier.dart';
import '../models/project.dart';
import '../models/product.dart';
import '../invoice_ai/models.dart'; // Para DolibarrInvoiceResult
import 'supplier_form_screen.dart';

class InvoiceFormScreen extends StatefulWidget {
  final SupplierInvoice? invoice;

  const InvoiceFormScreen({super.key, this.invoice});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _refController;
  late TextEditingController _refSupplierController;
  late TextEditingController _dateController;
  late TextEditingController _totalHtController;
  late TextEditingController _totalTtcController;
  late TextEditingController _totalVatController;
  late TextEditingController _noteController;
  late TextEditingController _lineDescriptionController;
  late TextEditingController _lineQtyController;
  late TextEditingController _lineSubpriceController;
  late TextEditingController _lineDiscountController;
  late TextEditingController _lineVatController;

  List<Supplier> _suppliers = [];
  List<Project> _projects = [];
  List<Map<String, dynamic>> _paymentTerms = [];
  List<Map<String, dynamic>> _paymentModes = [];
  List<InvoiceLine> _lines = [];
  // Rastrear qué líneas vienen del OCR (escaneadas) vs ingreso manual
  final Set<int> _scannedLineIndices = {};
  Supplier? _selectedSupplier;
  Project? _selectedProject;
  String? _selectedClasificacion;
  // Campos de condiciones de pago
  int? _selectedCondReglementId;
  String? _selectedDateLimReglement;
  int? _selectedModeReglementId;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isProcessingImage = false;
  bool _globalPricesIncludeVat = false; // Aplica a TODOS los productos
  bool _userEditedDueDate = false; // Indica si la fecha de vencimiento fue editada manualmente
  late TextEditingController _dateLimReglementController;
  // Estado de edición en línea
  int? _editingLineIndex;
  // Controladores de la línea editada actualmente
  late TextEditingController _editDescriptionController;
  late TextEditingController _editQtyController;
  late TextEditingController _editSubpriceController;
  late TextEditingController _editDiscountController;
  late TextEditingController _editVatController;
  bool _editPricesIncludeVat = false;

  // Mapa: Etiqueta (UI) → Valor almacenado en Dolibarr (minúsculas, sin acentos, con underscore)
  static const Map<String, String> _clasificacionValueMap = {
    'Materiales': 'materiales',
    'Combustible': 'combustible',
    'Alimentación': 'alimentacion',
    'EPP (Elementos de Protección Personal)': 'epp',
    'Servicio': 'servicio',
    'Gasto General': 'gasto_general',
  };

  static const List<String> _clasificacionOptions = [
    'Materiales',
    'Combustible',
    'Alimentación',
    'EPP (Elementos de Protección Personal)',
    'Servicio',
    'Gasto General',
  ];

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(text: widget.invoice?.ref ?? '');
    _refSupplierController =
        TextEditingController(text: widget.invoice?.refSupplier ?? '');
    // Mostrar la fecha en formato YYYY-MM-DD.
    _dateController = TextEditingController(text: _formatDateForDisplay(widget.invoice?.date));
    _totalHtController =
        TextEditingController(text: widget.invoice?.totalHt?.toString() ?? '');
    _totalTtcController =
        TextEditingController(text: widget.invoice?.totalTtc?.toString() ?? '');
    _totalVatController =
        TextEditingController(text: widget.invoice?.totalVat?.toString() ?? '');
    _noteController =
        TextEditingController(text: widget.invoice?.notePublic ?? '');
    // Normalizar clasificación para que coincida con opciones del dropdown (valor almacenado → etiqueta)
    final rawClasificacion = widget.invoice?.clasificacion;
    _selectedClasificacion = rawClasificacion != null && rawClasificacion.isNotEmpty
        ? _clasificacionValueMap.entries
            .firstWhere(
              (entry) => entry.value.toLowerCase() == rawClasificacion.toLowerCase(),
              orElse: () => MapEntry(rawClasificacion, rawClasificacion),
            )
            .key
        : null;
    _lineDescriptionController = TextEditingController();
    _lineQtyController = TextEditingController(text: '1');
    _lineSubpriceController = TextEditingController();
    _lineDiscountController = TextEditingController(text: '0');
    _lineVatController = TextEditingController(text: '19');

    // Controladores de edición (inicialización diferida cuando se necesitan)
    _editDescriptionController = TextEditingController();
    _editQtyController = TextEditingController();
    _editSubpriceController = TextEditingController();
    _editDiscountController = TextEditingController();
    _editVatController = TextEditingController();

    // Inicializar la fecha de vencimiento con el mismo formato de la factura.
    _dateLimReglementController = TextEditingController(
      text: _formatDateForDisplay(widget.invoice?.dateLimReglement ?? widget.invoice?.date),
    );

    // Rastrear si el usuario editó manualmente la fecha de vencimiento
    _userEditedDueDate = widget.invoice?.dateLimReglement != null &&
                         widget.invoice?.dateLimReglement != widget.invoice?.date;

    // Actualizar automáticamente el vencimiento mientras el usuario no lo edite.
    _dateController.addListener(_onInvoiceDateChanged);

    if (widget.invoice?.lines != null) {
      _lines = List<InvoiceLine>.from(widget.invoice!.lines!);
      // Las líneas existentes se consideran manuales, no escaneadas.
      _scannedLineIndices.clear();
      _syncTotalsFromLines();
    }
    _loadSuppliersAndProjects();
  }

  @override
  void dispose() {
    _refController.dispose();
    _refSupplierController.dispose();
    _dateController.removeListener(_onInvoiceDateChanged);
    _dateController.dispose();
    _dateLimReglementController.dispose();
    _totalHtController.dispose();
    _totalTtcController.dispose();
    _totalVatController.dispose();
    _noteController.dispose();
    _lineDescriptionController.dispose();
    _lineQtyController.dispose();
    _lineSubpriceController.dispose();
    _lineDiscountController.dispose();
    _lineVatController.dispose();
    _editDescriptionController.dispose();
    _editQtyController.dispose();
    _editSubpriceController.dispose();
    _editDiscountController.dispose();
    _editVatController.dispose();
    super.dispose();
  }

  void _onInvoiceDateChanged() {
    if (!_userEditedDueDate && _dateController.text.isNotEmpty) {
      // Actualizar solo mientras el usuario no haya personalizado el vencimiento.
      setState(() {
        _selectedDateLimReglement = _dateController.text;
        _dateLimReglementController.text = _dateController.text;
      });
    }
  }

  /// Asegura que la fecha esté en formato YYYY-MM-DD para mostrar en campos de texto
  String _formatDateForDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return date.toIso8601String().split('T')[0];
    } catch (_) {
      // Si ya está en formato correcto o no se puede parsear, se conserva.
      return dateStr;
    }
  }

  double _parseAmount(String value) =>
      double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double _roundAmount(double value) => (value * 100).roundToDouble() / 100;

  String _getPaymentModeLabel(Map<String, dynamic> mode) {
    final label = mode['label']?.toString() ?? '';
    final code = mode['code']?.toString().toUpperCase() ?? '';

    // Si existe label y parece estar en español (contiene palabras comunes en español), usarlo
    if (label.isNotEmpty) {
      // Usar la etiqueta si ya está en español o parece descriptiva.
      const spanishKeywords = ['transferencia', 'efectivo', 'tarjeta', 'cheque', 'domiciliacion', 'paypal', 'stripe', 'bizum'];
      final lowerLabel = label.toLowerCase();
      if (spanishKeywords.any(lowerLabel.contains) || !RegExp(r'^[A-Z0-9_]+$').hasMatch(label)) {
        return label;
      }
    }

    // En caso contrario, mapear códigos comunes a etiquetas en español
    switch (code) {
      case 'VIR':
      case 'TRANSFER':
      case 'TRA':
        return 'Transferencia bancaria';
      case 'LIQ':
        return 'Liquidación';
      case 'ESP':
        return 'Efectivo';
      case 'CHQ':
      case 'CHEQUE':
        return 'Cheque';
      case 'CAR':
      case 'CARTE':
      case 'CARD':
        return 'Tarjeta de crédito/débito';
      case 'PRE':
      case 'PREL':
        return 'Preliminar';
      case 'DOM':
      case 'DOMI':
        return 'Domiciliación bancaria';
      case 'PPL':
      case 'PAYPAL':
        return 'PayPal';
      case 'STR':
      case 'STRIPE':
        return 'Stripe';
      case 'BIZ':
      case 'BIZUM':
        return 'Bizum';
      default:
        return label.isNotEmpty ? label : (code.isNotEmpty ? code : 'Desconocido');
    }
  }

  String _getPaymentTermLabel(Map<String, dynamic> term) {
    final label = term['label']?.toString() ?? '';
    final code = term['code']?.toString().toUpperCase() ?? '';

    // Si existe label y parece estar en español (contiene palabras comunes en español), usarlo
    if (label.isNotEmpty) {
      const spanishKeywords = ['entrega', 'dí­a', 'días', 'mes', 'meses', 'fin de mes', 'contado', 'recepción', 'factura'];
      final lowerLabel = label.toLowerCase();
      if (spanishKeywords.any(lowerLabel.contains) || !RegExp(r'^[A-Z0-9_]+$').hasMatch(label)) {
        return label;
      }
    }

    // En caso contrario, mapear códigos comunes a etiquetas en español
    switch (code) {
      case 'CASH':
      case 'CONTADO':
      case 'IMMEDIATE':
        return 'Contado';
      case 'DELIVERY':
      case 'ENTREGA':
      case 'ON_DELIVERY':
        return 'A la entrega';
      case '30D':
      case '30_DAYS':
      case 'NET30':
        return '30 días';
      case '45D':
      case '45_DAYS':
      case 'NET45':
        return '45 días';
      case '60D':
      case '60_DAYS':
      case 'NET60':
        return '60 días';
      case '90D':
      case '90_DAYS':
      case 'NET90':
        return '90 días';
      case 'EOM':
      case 'END_OF_MONTH':
      case 'FIN_MES':
        return 'Fin de mes';
      case 'EOM30':
      case '30_EOM':
        return '30 días fin de mes';
      case 'EOM60':
      case '60_EOM':
        return '60 días fin de mes';
      case '15D':
      case '15_DAYS':
      case 'NET15':
        return '15 días';
      case 'ADVANCE':
      case 'ANTICIPO':
      case 'PREPAYMENT':
        return 'Anticipo/Prepago';
      default:
        return label.isNotEmpty ? label : (code.isNotEmpty ? code : 'Desconocido');
    }
  }

  double _lineNet(InvoiceLine line) {
    final qty = line.qty ?? 0;
    final subprice = line.subprice ?? 0;
    final discount = line.remisePercent ?? 0;
    final vatRate = line.tvaTx ?? 0;

    // Si los precios incluyen IVA (checkbox global), el precio unitario ya tiene IVA incluido
    // Neto = (precio_con_iva / (1 + iva/100)) * cantidad * (1 - descuento/100)
    if (_globalPricesIncludeVat && vatRate > 0) {
      final unitNet = subprice / (1 + vatRate / 100);
      return _roundAmount(qty * unitNet * (1 - discount / 100));
    }

    // Precio sin IVA (comportamiento original)
    return _roundAmount(qty * subprice * (1 - discount / 100));
  }

  double _lineVat(InvoiceLine line) {
    final net = _lineNet(line);
    final vatRate = line.tvaTx ?? 0;

    // Si los precios incluyen IVA (checkbox global), el IVA es la diferencia
    if (_globalPricesIncludeVat && vatRate > 0) {
      final qty = line.qty ?? 0;
      final subprice = line.subprice ?? 0;
      final discount = line.remisePercent ?? 0;
      final grossTotal = _roundAmount(qty * subprice * (1 - discount / 100));
      return _roundAmount(grossTotal - net);
    }

    // Calculo normal: IVA = Neto * tasa_iva / 100
    return _roundAmount(net * vatRate / 100);
  }

  String _formatAmount(double value) => value.toStringAsFixed(2);

  void _syncTotalsFromLines() {
    final totalHt = _lines.fold<double>(0, (sum, line) {
      return sum + _lineNet(line);
    });
    final totalVat = _lines.fold<double>(0, (sum, line) {
      return sum + _lineVat(line);
    });
    final totalTtc = _roundAmount(totalHt + totalVat);

    _totalHtController.text = _formatAmount(_roundAmount(totalHt));
    _totalVatController.text = _formatAmount(_roundAmount(totalVat));
    _totalTtcController.text = _formatAmount(totalTtc);
  }

  void _addLineFromFields() {
    final description = _lineDescriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La descripcion de la linea es obligatoria')),
      );
      return;
    }

    final qty = _parseAmount(_lineQtyController.text);
    final subprice = _parseAmount(_lineSubpriceController.text);
    final discount = _parseAmount(_lineDiscountController.text);
    final vatRate = _parseAmount(_lineVatController.text);

    if (qty <= 0 || subprice < 0 || discount < 0 || discount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cantidad y precio unitario deben ser validos')),
      );
      return;
    }

    setState(() {
      _lines.add(
        InvoiceLine(
          description: description,
          qty: qty,
          subprice: subprice,
          remisePercent: discount,
          totalHt: _roundAmount(qty * subprice * (1 - discount / 100)),
          tvaTx: vatRate,
          pricesIncludeVat: _globalPricesIncludeVat,
        ),
      );
      _lineDescriptionController.clear();
      _lineQtyController.text = '1';
      _lineSubpriceController.clear();
      _lineDiscountController.text = '0';
      _lineVatController.text = '19';
      _syncTotalsFromLines();
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      // Actualizar índices escaneados: eliminar el índice borrado y desplazar los índices mayores hacia abajo
      _scannedLineIndices.remove(index);
      final updatedScanned = <int>{};
      for (final idx in _scannedLineIndices) {
        if (idx > index) {
          updatedScanned.add(idx - 1);
        } else {
          updatedScanned.add(idx);
        }
      }
      _scannedLineIndices
        ..clear()
        ..addAll(updatedScanned);
      _syncTotalsFromLines();
    });
  }

  Map<String, dynamic> _buildInvoicePayload() {
    final payload = <String, dynamic>{
      if (_selectedSupplier?.id != null) 'socid': _selectedSupplier!.id,
      if (_refSupplierController.text.trim().isNotEmpty)
        'ref_supplier': _refSupplierController.text.trim(),
      if (_dateController.text.trim().isNotEmpty)
        'date': _dateController.text.trim(),
      if (_selectedProject?.id != null) 'fk_project': _selectedProject!.id,
      if (_noteController.text.trim().isNotEmpty)
        'note_public': _noteController.text.trim(),
      // Campos de condiciones de pago
      if (_selectedCondReglementId != null) 'cond_reglement_id': _selectedCondReglementId,
      if (_selectedDateLimReglement != null && _selectedDateLimReglement!.isNotEmpty)
        'date_lim_reglement': _selectedDateLimReglement!,
      if (_selectedModeReglementId != null) 'mode_reglement_id': _selectedModeReglementId,
      // NO enviar 'clasificacion' como campo directo - Dolibarr lo ignora
    };

    // Extrafields (campos personalizados) - Dolibarr SOLO los procesa en array_options
    final arrayOptions = <String, dynamic>{};
    if (_selectedClasificacion != null && _selectedClasificacion!.isNotEmpty) {
      // Nombre técnico del extrafield en Dolibarr (configurado en Diccionarios > Campos extra)
      // Enviar el VALOR ALMACENADO (minúsculas, sin acentos, con underscore), NO la etiqueta
      final storedValue = _clasificacionValueMap[_selectedClasificacion!] ?? _selectedClasificacion!.toLowerCase();
      arrayOptions['options_clasificacion'] = storedValue;
    }
    if (arrayOptions.isNotEmpty) {
      payload['array_options'] = arrayOptions;
    }

    return payload;
  }

  String _normalizeReference(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  Future<bool> _supplierReferenceExists(
    DolibarrService service,
    String apiKey,
  ) async {
    final ref = _normalizeReference(_refSupplierController.text);
    if (ref.isEmpty) return false;

    final invoices = await service.getSupplierInvoices(apiKey);
    return invoices.any((invoice) {
      final existing =
          _normalizeReference(invoice['ref_supplier']?.toString() ?? '');
      final sameSupplier = _selectedSupplier?.id == null ||
          invoice['fk_soc']?.toString() == _selectedSupplier!.id.toString() ||
          invoice['socid']?.toString() == _selectedSupplier!.id.toString();
      return existing == ref && sameSupplier;
    });
  }

  Future<void> _loadSuppliersAndProjects() async {
    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();

    try {
      final suppliersData =
          await dolibarrService.getSuppliers(authService.apiKey!);
      final projectsData =
          await dolibarrService.getProjects(authService.apiKey!);
      final paymentTermsData =
          await dolibarrService.getPaymentTerms(authService.apiKey!);
      final paymentModesData =
          await dolibarrService.getPaymentModes(authService.apiKey!);

      setState(() {
        _suppliers =
            suppliersData.map((json) => Supplier.fromJson(json)).toList();
        _projects = projectsData.map((json) => Project.fromJson(json)).toList();
        _paymentTerms = paymentTermsData;
        _paymentModes = paymentModesData;

        if (widget.invoice?.fkSoc != null) {
          for (final s in _suppliers) {
            if (s.id == widget.invoice?.fkSoc) {
              _selectedSupplier = s;
              break;
            }
          }
        }

        if (widget.invoice?.fkProject != null) {
          for (final p in _projects) {
            if (p.id == widget.invoice?.fkProject) {
              _selectedProject = p;
              break;
            }
          }
        }

        // Cargar valores existentes de la factura si estamos editando
        if (widget.invoice != null) {
          _selectedCondReglementId = widget.invoice!.condReglementId;
          _selectedDateLimReglement = widget.invoice!.dateLimReglement;
          _selectedModeReglementId = widget.invoice!.modeReglementId;
        }

        // Establecer valores por defecto para nueva factura
        if (widget.invoice == null) {
          // Valor por defecto: "A la entrega" (por etiqueta o código conocido).
          final entregaTerm = _paymentTerms.firstWhere(
            (term) {
              final label = (term['label']?.toString() ?? '').toLowerCase();
              final code = (term['code']?.toString() ?? '').toLowerCase();
              return label.contains('entrega') || code == '1' || code == 'entrega';
            },
            orElse: () => _paymentTerms.isNotEmpty ? _paymentTerms.first : <String, dynamic>{},
          );
          if (entregaTerm.isNotEmpty && entregaTerm['id'] != null) {
            _selectedCondReglementId = entregaTerm['id'] as int;
          }

          // Fecha de vencimiento por defecto: mismo día de facturación.
          if (_dateController.text.isNotEmpty) {
            _selectedDateLimReglement = _dateController.text;
          }

          // Forma de pago por defecto: transferencia u otra forma preferida.
          final preferredModeCodes = ['VIR', 'TRANSFER', 'TRA', 'LIQ', 'ESP', 'TRANSFERENCIA'];
          final transferMode = _paymentModes.firstWhere(
            (mode) {
              final code = (mode['code']?.toString() ?? '').toUpperCase();
              return preferredModeCodes.contains(code);
            },
            orElse: () => _paymentModes.isNotEmpty ? _paymentModes.first : <String, dynamic>{},
          );
          if (transferMode.isNotEmpty && transferMode['id'] != null) {
            _selectedModeReglementId = transferMode['id'] as int;
          }
        }
      });
    } catch (e) {
      print('Error al cargar proveedores y proyectos: $e');
    }
  }

  Future<void> _createSupplierFromInvoice() async {
    final created = await Navigator.of(context).push<Supplier>(
      MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
    );
    if (created == null || !mounted) return;

    await _loadSuppliersAndProjects();
    if (!mounted) return;

    Supplier? selected;
    for (final supplier in _suppliers) {
      final sameId = created.id != null && supplier.id == created.id;
      final sameRut = created.rut != null &&
          created.rut!.isNotEmpty &&
          supplier.rut == created.rut;
      final sameName = supplier.name.trim().toLowerCase() ==
          created.name.trim().toLowerCase();
      if (sameId || sameRut || sameName) {
        selected = supplier;
        break;
      }
    }

    if (selected != null) {
      setState(() => _selectedSupplier = selected);
    }
  }

  Supplier? _findSupplierByRut(String rut) {
    for (final s in _suppliers) {
      if (s.rut != null && s.rut!.trim() == rut) return s;
    }
    return null;
  }

  Supplier? _findSupplierByName(String name) {
    final lowerName = name.toLowerCase();
    for (final s in _suppliers) {
      if (s.name.trim().toLowerCase() == lowerName) return s;
    }
    return null;
  }

  Supplier? _findSupplierById(int id) {
    for (final s in _suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _createOrSelectSupplierFromOcr(DolibarrInvoiceResult extractedData) async {
    // Si ya tenemos un proveedor seleccionado, no sobrescribir
    if (_selectedSupplier != null) return;

    final supplierName = extractedData.supplier?.trim();
    final supplierRut = extractedData.supplierRut?.trim();

    if (supplierName == null || supplierName.isEmpty) return;

    // Intentar encontrar proveedor existente en Dolibarr por RUT o nombre
    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();

    Supplier? existingSupplier;
    if (supplierRut != null && supplierRut.isNotEmpty) {
      final found = await dolibarrService.findSupplierByRut(supplierRut, authService.apiKey!);
      if (found != null) {
        existingSupplier = Supplier.fromJson(found);
      }
    }
    if (existingSupplier == null) {
      final found = await dolibarrService.findSupplierByName(supplierName, authService.apiKey!);
      if (found != null) {
        existingSupplier = Supplier.fromJson(found);
      }
    }

    // También verificar proveedores cargados localmente como respaldo
    existingSupplier ??= _findSupplierByRut(supplierRut ?? '');
    existingSupplier ??= _findSupplierByName(supplierName);

    if (existingSupplier != null) {
      // Proveedor encontrado, seleccionarlo
      setState(() => _selectedSupplier = existingSupplier);
      return;
    }

    // Crear nuevo proveedor con todos los datos disponibles del OCR
    final newSupplier = Supplier(
      name: supplierName,
      rut: supplierRut,
      // Nota: giro, dirección, ciudad, email y teléfono ya existen en Supplier;
      // si el OCR los entrega, deben mapearse antes de crear el proveedor.
    );

    try {
      final createdId = await dolibarrService.createSupplier(
        newSupplier.toJson(),
        authService.apiKey!,
      );
      // Recargar proveedores para obtener el proveedor creado completo con ID
      await _loadSuppliersAndProjects();
      if (!mounted) return;

      // Buscar el proveedor recién creado
      final created = _findSupplierById(createdId);
      if (created != null) {
        setState(() => _selectedSupplier = created);
      }
    } catch (e) {
      print('Error creating supplier from OCR: $e');
      // Fallar silenciosamente - el usuario puede crear/seleccionar proveedor manualmente
    }
  }

  Future<void> _showCreateSupplierDialog() async {
    final result = await showDialog<Supplier>(
      context: context,
      builder: (context) => _CreateSupplierDialog(
        onCreate: (supplier) async {
          final authService = context.read<AuthService>();
          final dolibarrService = context.read<DolibarrService>();
          final id = await dolibarrService.createSupplier(
            supplier.toJson(),
            authService.apiKey!,
          );
          return supplier.copyWith(id: id);
        },
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSupplier = result;
        _suppliers = [..._suppliers, _selectedSupplier!]
          ..sort((a, b) => a.name.compareTo(b.name));
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime initialDate;
    if (widget.invoice?.date != null && widget.invoice!.date!.isNotEmpty) {
      final parsed = DateTime.tryParse(widget.invoice!.date!);
      if (parsed != null) {
        // Ajustar al rango válido para evitar errores de aserción en showDatePicker
        if (parsed.isBefore(DateTime(2000))) {
          initialDate = DateTime(2000);
        } else if (parsed.isAfter(DateTime(2100))) {
          initialDate = DateTime(2100);
        } else {
          initialDate = parsed;
        }
      } else {
        initialDate = DateTime.now();
      }
    } else {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _dateController.text = picked.toIso8601String().split('T')[0];
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _processImageWithOcr();
    }
  }

  Future<void> _processImageWithOcr() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessingImage = true;
    });

    final invoiceAiService = context.read<InvoiceAiService>();

    try {
      final extractedData =
          await invoiceAiService.processImage(_selectedImage!);
      final extractedJson = extractedData.toJson();

      print('ExtractedData object: $extractedData');
      print('ExtractedData.refSupplier: ${extractedData.refSupplier}');
      print('ExtractedData.date: ${extractedData.date}');
      print('ExtractedData.totalHt: ${extractedData.totalHt}');
      print('ExtractedData.totalTtc: ${extractedData.totalTtc}');
      print('ExtractedData.totalTva: ${extractedData.totalTva}');
      print('ExtractedData.items: ${extractedData.items}');
      print('ExtractedJson: $extractedJson');

      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          // Usar directamente el objeto extractedData en lugar de toJson()!
          if (extractedData.refSupplier != null) {
            print(
                'Setting refSupplierController to: ${extractedData.refSupplier}');
            _refSupplierController.text = extractedData.refSupplier!;
          }
          if (extractedData.date != null) {
            print('Setting dateController to: ${extractedData.date}');
            _dateController.text = extractedData.date!;
          }

          // Establecer campos de pago desde datos OCR si están disponibles
          if (extractedData.condReglementId != null) {
            _selectedCondReglementId = extractedData.condReglementId;
          }
          if (extractedData.dateLimReglement != null) {
            _selectedDateLimReglement = extractedData.dateLimReglement;
          } else if (extractedData.date != null) {
            // Si no hay fecha límite específica, usar fecha de factura por defecto
            _selectedDateLimReglement = extractedData.date;
          }
          if (extractedData.modeReglementId != null) {
            _selectedModeReglementId = extractedData.modeReglementId;
          }

          if (extractedData.items.isNotEmpty) {
            final newLines = extractedData.items.map((item) {
              final qty = item.qty.toDouble();
              final subprice = double.tryParse(item.subprice) ?? 0;
              return InvoiceLine(
                description: item.description,
                qty: qty,
                subprice: subprice,
                remisePercent: item.remisePercent.toDouble(),
                totalHt: _roundAmount(
                    qty * subprice * (1 - item.remisePercent / 100)),
                tvaTx: item.tvaTx.toDouble(),
                pricesIncludeVat: item.priceIncludesVat,
              );
            }).toList();

            setState(() {
              _lines = newLines;
              // Marcar todas las líneas nuevas como escaneadas.
              _scannedLineIndices.clear();
              for (int i = 0; i < newLines.length; i++) {
                _scannedLineIndices.add(i);
              }
              // Definir el selector global según el primer producto extraído.
              _globalPricesIncludeVat = extractedData.items.first.priceIncludesVat;
              _syncTotalsFromLines();
            });
          }
        });

        // Crear o seleccionar proveedor usando los datos del OCR.
        await _createOrSelectSupplierFromOcr(extractedData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos extraídos correctamente de la factura'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _processImageWithOcr: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isProcessingImage = false;
      });
      if (mounted) {
        final detail = e.toString().replaceFirst('Exception: ', '');
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('No se pudo autocompletar'),
            content: SingleChildScrollView(
              child: Text(
                '$detail\n\nNo se modificaron las lineas ni los montos. Verifica la conexion, la API key de Gemini o intenta nuevamente con una foto mas nitida.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();

    if (_selectedSupplier?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un proveedor')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes agregar al menos una linea de factura')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      if (widget.invoice?.id == null &&
          await _supplierReferenceExists(
              dolibarrService, authService.apiKey!)) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              icon:
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              title: const Text('Factura ya registrada'),
              content: Text(
                'Ya existe una factura del proveedor con la referencia ${_refSupplierController.text.trim()}. Revisa el folio o edita la factura existente.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final payload = _buildInvoicePayload();

      if (widget.invoice?.id != null) {
        await dolibarrService.updateSupplierInvoice(
          widget.invoice!.id!,
          payload,
          authService.apiKey!,
        );
      } else {
        await dolibarrService.createAndFinalizeSupplierInvoice(
          header: payload,
          lines: _lines.map((line) => line.toJson()).toList(),
          invoiceDate: _dateController.text.trim(),
          apiKey: authService.apiKey!,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.invoice?.id != null
                ? 'Factura actualizada correctamente'
                : 'Factura creada, validada y pagada correctamente'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final message = e.toString().contains('ErrorRefAlreadyExists')
            ? 'Ya existe una factura con esta Ref. Proveedor en Dolibarr. Cambia el folio o edita la factura existente.'
            : 'Error al guardar: ${e.toString()}';
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('No se pudo completar la carga'),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.invoice?.id != null ? 'Editar Factura' : 'Nueva Factura'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escaneo de Factura',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.document_scanner,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Sin imagen',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Escanear Factura'),
                          ),
                        ),
                        if (_selectedImage != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.red),
                          ),
                        ],
                      ],
                    ),
                    if (_isProcessingImage) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Procesando imagen con ML Kit OCR...'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de la Factura',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _refController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia interna (opcional)',
                        prefixIcon: Icon(Icons.tag),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _refSupplierController,
                      decoration: const InputDecoration(
                        labelText: 'Ref. Proveedor',
                        prefixIcon: Icon(Icons.receipt_long),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Fecha factura *',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: _selectDate,
                        ),
                      ),
                      readOnly: true,
                      onTap: _selectDate,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La fecha es obligatoria';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Condiciones de Pago',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Condiciones de pago (cond_reglement_id)
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCondReglementId,
                      decoration: const InputDecoration(
                        labelText: 'Condiciones de pago *',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentTerms.map((term) {
                        final id = _parseInt(term['id']);
                        final label = _getPaymentTermLabel(term);
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(label),
                        );
                      }).where((item) => item.value != null).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCondReglementId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Debe seleccionar una condición de pago';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Fecha limite de pago (date_lim_reglement)
                    TextFormField(
                      controller: _dateLimReglementController,
                      decoration: InputDecoration(
                        labelText: 'Fecha lí­mite de pago *',
                        prefixIcon: const Icon(Icons.event),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDateLimReglement != null
                                  ? DateTime.tryParse(_selectedDateLimReglement!) ?? DateTime.now()
                                  : DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _userEditedDueDate = true;
                                _selectedDateLimReglement = picked.toIso8601String().split('T')[0];
                                _dateLimReglementController.text = _selectedDateLimReglement!;
                              });
                            }
                          },
                        ),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateLimReglement != null
                              ? DateTime.tryParse(_selectedDateLimReglement!) ?? DateTime.now()
                              : DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _userEditedDueDate = true;
                            _selectedDateLimReglement = picked.toIso8601String().split('T')[0];
                            _dateLimReglementController.text = _selectedDateLimReglement!;
                          });
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _userEditedDueDate = true;
                          _selectedDateLimReglement = value.trim().isEmpty ? null : value.trim();
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La fecha lí­mite es obligatoria';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Forma de pago (mode_reglement_id)
                    DropdownButtonFormField<int>(
                      initialValue: _selectedModeReglementId,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pago *',
                        prefixIcon: Icon(Icons.credit_card),
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentModes.map((mode) {
                        final id = _parseInt(mode['id']);
                        final label = _getPaymentModeLabel(mode);
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(label),
                        );
                      }).where((item) => item.value != null).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedModeReglementId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Debe seleccionar una forma de pago';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proveedor',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Supplier>(
                      initialValue: _selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Proveedor *',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      items: _suppliers.map((supplier) {
                        return DropdownMenuItem(
                          value: supplier,
                          child: Text(supplier.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplier = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Debes seleccionar un proveedor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _showCreateSupplierDialog,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Agregar proveedor'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proyecto',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Project>(
                      initialValue: _selectedProject,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Proyecto (Opcional)',
                        prefixIcon: Icon(Icons.folder),
                        border: OutlineInputBorder(),
                      ),
                      items: _projects.map((project) {
                        return DropdownMenuItem(
                          value: project,
                          child: Text('${project.ref} - ${project.title}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProject = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _createSupplierFromInvoice,
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Crear proveedor'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clasificación',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedClasificacion,
                      decoration: const InputDecoration(
                        labelText: 'Clasificación *',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _clasificacionOptions.map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedClasificacion = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La clasificación es obligatoria';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lineas de factura',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (_lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'No hay lineas agregadas todavia',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    if (_lines.isNotEmpty) ...[
                      // Encabezado con selector global y botón para agregar.
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Precios con IVA incluido'),
                              subtitle: const Text(
                                'El precio unitario de TODOS los productos ya incluye IVA',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _globalPricesIncludeVat,
                              onChanged: (value) {
                                setState(() {
                                  _globalPricesIncludeVat = value ?? false;
                                  _syncTotalsFromLines(); // Recalcula totales al cambiar
                                });
                              },
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          IconButton(
                            onPressed: _showAddLineBottomSheet,
                            icon: const Icon(Icons.add_box),
                            tooltip: 'Agregar producto/servicio',
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Lista de li­neas con edicion inline (ExpansionTile)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildEditableLineCard(index),
                      ),
                      const SizedBox(height: 16),
                      // Formulario para agregar nueva li­nea manual (al final)
                      _buildAddLineForm(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Montos del documento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalHtController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Neto',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalVatController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'IVA',
                        prefixIcon: Icon(Icons.percent),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalTtcController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Total',
                        prefixIcon: Icon(Icons.payments),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Nota Publica',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveInvoice,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una tarjeta editable para una li­nea de factura.
  /// Modo vista (colapsado) -> muestra resumen + iconos editar/eliminar.
  /// Modo edición (expandido) -> formulario inline con todos los campos.
  Widget _buildEditableLineCard(int index) {
    final line = _lines[index];
    final isScanned = _scannedLineIndices.contains(index);
    final net = _lineNet(line);
    final vat = _lineVat(line);
    final total = _roundAmount(net + vat);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: _editingLineIndex == index,
        onExpansionChanged: (expanded) {
          if (expanded) {
            _startEditingLine(index);
          } else {
            _cancelEditingLine();
          }
        },
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isScanned
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            isScanned ? Icons.document_scanner : Icons.edit_note,
            size: 16,
            color: isScanned
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          line.description ?? 'Lí­nea ${index + 1}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatAmount(line.qty ?? 0)} — ${_formatAmount(line.subprice ?? 0)} = ${_formatAmount(total)}'
              '${line.remisePercent != null && line.remisePercent! > 0 ? ' (dscto: ${_formatAmount(line.remisePercent!)}%)' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _editingLineIndex == index ? 'Guardar' : 'Editar',
              icon: Icon(
                _editingLineIndex == index ? Icons.check : Icons.edit,
                color: _editingLineIndex == index ? Colors.green : null,
              ),
              onPressed: () {
                if (_editingLineIndex == index) {
                  _saveEditedLine(index);
                } else {
                  setState(() => _editingLineIndex = index);
                }
              },
            ),
            IconButton(
              tooltip: 'Eliminar lí­nea',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeLine(index),
            ),
          ],
        ),
        children: [
          if (_editingLineIndex == index) _buildLineEditForm(index),
        ],
      ),
    );
  }

  /// Inicia la edición de una lí­nea: precarga controllers con valores actuales.
  void _startEditingLine(int index) {
    final line = _lines[index];
    _editDescriptionController.text = line.description ?? '';
    _editQtyController.text = _formatAmount(line.qty ?? 1);
    _editSubpriceController.text = _formatAmount(line.subprice ?? 0);
    _editDiscountController.text = _formatAmount(line.remisePercent ?? 0);
    _editVatController.text = _formatAmount(line.tvaTx ?? 19);
    _editPricesIncludeVat = line.pricesIncludeVat ?? _globalPricesIncludeVat;
    setState(() => _editingLineIndex = index);
  }

  /// Cancela la edición: limpia estado sin guardar.
  void _cancelEditingLine() {
    setState(() => _editingLineIndex = null);
  }

  /// Guarda los cambios de la lí­nea editada.
  void _saveEditedLine(int index) {
    final description = _editDescriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La descripción es obligatoria')),
      );
      return;
    }

    final qty = _parseAmount(_editQtyController.text);
    final subprice = _parseAmount(_editSubpriceController.text);
    final discount = _parseAmount(_editDiscountController.text);
    final vatRate = _parseAmount(_editVatController.text);

    if (qty <= 0 || subprice < 0 || discount < 0 || discount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad y precio unitario deben ser válidos')),
      );
      return;
    }

    setState(() {
      _lines[index] = _lines[index].copyWith(
        description: description,
        qty: qty,
        subprice: subprice,
        remisePercent: discount,
        totalHt: _roundAmount(qty * subprice * (1 - discount / 100)),
        tvaTx: vatRate,
        pricesIncludeVat: _editPricesIncludeVat,
      );
      _editingLineIndex = null;
      _syncTotalsFromLines();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lí­nea "$description" actualizada'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Formulario de edición inline (visible dentro del ExpansionTile expandido).
  Widget _buildLineEditForm(int index) {
    final line = _lines[index];
    final net = _lineNet(line);
    final vat = _lineVat(line);
    final total = _roundAmount(net + vat);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vista previa en tiempo real
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista previa',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatAmount(_parseAmount(_editQtyController.text))} — ${_formatAmount(_parseAmount(_editSubpriceController.text))} = ${_formatAmount(_roundAmount(_parseAmount(_editQtyController.text) * _parseAmount(_editSubpriceController.text) * (1 - _parseAmount(_editDiscountController.text) / 100)))}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (_parseAmount(_editDiscountController.text) > 0)
                  Text(
                    'Descuento: ${_formatAmount(_parseAmount(_editDiscountController.text))}% | IVA: ${_formatAmount(_parseAmount(_editVatController.text))}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                Text(
                  'Neto: ${_formatAmount(net)} | Total: ${_formatAmount(total)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _editDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción *',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _editQtyController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}), // Actualizar vista previa
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _editSubpriceController,
                  decoration: const InputDecoration(
                    labelText: 'Precio unitario *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _editDiscountController,
                  decoration: const InputDecoration(
                    labelText: 'Descuento %',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _editVatController,
                  decoration: const InputDecoration(
                    labelText: 'IVA %',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Precio con IVA'),
                  subtitle: const Text('Este precio ya incluye IVA', style: TextStyle(fontSize: 11)),
                  value: _editPricesIncludeVat,
                  onChanged: (value) {
                    setState(() => _editPricesIncludeVat = value ?? false);
                  },
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelEditingLine,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveEditedLine(index),
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formulario para agregar nueva lí­nea manual (al final de la lista)
  Widget _buildAddLineForm() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Agregar lí­nea manual',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lineDescriptionController,
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
                    controller: _lineQtyController,
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
                    controller: _lineSubpriceController,
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lineDiscountController,
                    decoration: const InputDecoration(
                      labelText: 'Descuento %',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lineVatController,
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
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addLineFromFields,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar lí­nea'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Sheet para agregar lí­nea (modal mas visible)
  Future<void> _showAddLineBottomSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddLineBottomSheet(
        initialDescription: _lineDescriptionController.text,
        initialQty: _lineQtyController.text,
        initialSubprice: _lineSubpriceController.text,
        initialDiscount: _lineDiscountController.text,
        initialVat: _lineVatController.text,
        onSearchProducts: _searchDolibarrProducts,
        pricesIncludeVat: _globalPricesIncludeVat,
      ),
    );

    if (result != null && mounted) {
      // Si se seleccionó un producto del catálogo, usar esos datos
      if (result['fromCatalog'] == true) {
        _lineDescriptionController.text = result['description'] ?? '';
        _lineQtyController.text = result['qty']?.toString() ?? '1';
        _lineSubpriceController.text = result['subprice']?.toString() ?? '';
        _lineDiscountController.text = result['discount']?.toString() ?? '0';
        _lineVatController.text = result['vat']?.toString() ?? '19';
        // Agregar directamente
        _addLineFromFields();
      } else if (result['action'] == 'add_manual') {
        // Solo abrir el formulario manual (ya está en pantalla)
        _scrollToAddLineForm();
      }
    }
  }

  /// Scroll hacia el formulario de agregar lí­nea al final
  void _scrollToAddLineForm() {
    // El formulario ya está visible al final, pero podríamos agregar animación
    // si está dentro de un Scrollable
  }

  /// Buscar productos en catálogo de Dolibarr
  Future<void> _searchDolibarrProducts() async {
    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();

    if (authService.apiKey == null) return;

    try {
      // Buscar productos/servicios (type 0 = producto, 1 = servicio)
      final result = await dolibarrService.get(
        'products?limit=100&sortfield=label&sortorder=ASC',
        authService.apiKey!,
      );
      final rawProducts = _asList(result);
      final products = rawProducts.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();

      if (!mounted) return;

      final selected = await showSearch<Product?>(
        context: context,
        delegate: _ProductSearchDelegate(products: products),
      );

      if (selected != null && mounted) {
        // Retornar el producto seleccionado al bottom sheet
        Navigator.of(context).pop({
          'fromCatalog': true,
          'description': selected.label,
          'qty': 1.0,
          'subprice': selected.price,
          'discount': 0.0,
          'vat': selected.tvaTx?.toDouble() ?? 19.0,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error buscando productos: $e')),
        );
      }
    }
  }

  /// Convierte una respuesta de la API a una lista.
  List<dynamic> _asList(dynamic value) {
    if (value is List) return value.cast<dynamic>();
    if (value is Map && value['data'] is List) return (value['data'] as List).cast<dynamic>();
    return <dynamic>[];
  }
}

class _AddLineBottomSheet extends StatelessWidget {
  final String initialDescription;
  final String initialQty;
  final String initialSubprice;
  final String initialDiscount;
  final String initialVat;
  final VoidCallback onSearchProducts;
  final bool pricesIncludeVat;

  const _AddLineBottomSheet({
    required this.initialDescription,
    required this.initialQty,
    required this.initialSubprice,
    required this.initialDiscount,
    required this.initialVat,
    required this.onSearchProducts,
    required this.pricesIncludeVat,
  });

  @override
  Widget build(BuildContext context) {
    final descriptionController = TextEditingController(text: initialDescription);
    final qtyController = TextEditingController(text: initialQty);
    final subpriceController = TextEditingController(text: initialSubprice);
    final discountController = TextEditingController(text: initialDiscount);
    final vatController = TextEditingController(text: initialVat);
    final formKey = GlobalKey<FormState>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_box, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Agregar producto/servicio',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop({'action': 'add_manual'}),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Completa los datos o busca en el catálogo de Dolibarr',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              // Botón buscar en catálogo
              OutlinedButton.icon(
                onPressed: onSearchProducts,
                icon: const Icon(Icons.search),
                label: const Text('Buscar en catálogo de Dolibarr'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Formulario manual
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: subpriceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: discountController,
                      decoration: const InputDecoration(
                        labelText: 'Descuento %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: vatController,
                      decoration: const InputDecoration(
                        labelText: 'IVA %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Precio con IVA'),
                      subtitle: const Text('Este precio ya incluye IVA', style: TextStyle(fontSize: 11)),
                      value: pricesIncludeVat,
                      onChanged: (value) {},
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop({'action': 'add_manual'}),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.of(context).pop({
                            'action': 'add_manual',
                            'description': descriptionController.text,
                            'qty': double.tryParse(qtyController.text) ?? 1,
                            'subprice': double.tryParse(subpriceController.text) ?? 0,
                            'discount': double.tryParse(discountController.text) ?? 0,
                            'vat': double.tryParse(vatController.text) ?? 19,
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar línea'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSearchDelegate extends SearchDelegate<Product?> {
  final List<Product> products;

  _ProductSearchDelegate({required this.products});

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final filtered = products.where((p) =>
        p.label.toLowerCase().contains(query.toLowerCase()) ||
        (p.ref?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
        (p.code?.toLowerCase().contains(query.toLowerCase()) ?? false)).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No se encontraron productos'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final p = filtered[index];
        return ListTile(
          leading: Icon(p.type == 0 ? Icons.inventory_2 : Icons.miscellaneous_services),
          title: Text(p.label),
          subtitle: Text(
              'Ref: ${p.ref ?? '—'} | Precio: ${p.price ?? '—'} | IVA: ${p.tvaTx ?? 0}%'),
          onTap: () => close(context, p),
        );
      },
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context);
}

class _CreateSupplierDialog extends StatefulWidget {
  final Future<Supplier> Function(Supplier) onCreate;

  const _CreateSupplierDialog({required this.onCreate});

  @override
  State<_CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends State<_CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rutController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _giroController = TextEditingController();
  final _contactNameController = TextEditingController();
  var _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rutController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _giroController.dispose();
    _contactNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo proveedor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre o razón social *',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'El nombre es obligatorio'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rutController,
                decoration: const InputDecoration(
                  labelText: 'RUT',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _giroController,
                decoration: const InputDecoration(
                  labelText: 'Giro / Actividad',
                  prefixIcon: Icon(Icons.work),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNameController,
                decoration: const InputDecoration(
                  labelText: 'Persona de contacto',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'País',
                  prefixIcon: Icon(Icons.public),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isSaving = true);
                  final supplier = Supplier(
                    name: _nameController.text.trim(),
                    rut: _rutController.text.trim(),
                    email: _emailController.text.trim(),
                    phone: _phoneController.text.trim(),
                    address: _addressController.text.trim(),
                    city: _cityController.text.trim(),
                    country: _countryController.text.trim(),
                    giro: _giroController.text.trim(),
                    contactName: _contactNameController.text.trim(),
                  );
                  try {
                    final createdSupplier = await widget.onCreate(supplier);
                    if (!context.mounted) return;
                    Navigator.pop(context, createdSupplier);
                  } catch (error) {
                    setState(() => _isSaving = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo crear el proveedor: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear y seleccionar'),
        ),
      ],
    );
  }
}

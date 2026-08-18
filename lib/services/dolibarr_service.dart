import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración de la API de Dolibarr.
/// La URL base se obtiene desde variables de entorno (dart-define) en tiempo de compilación
/// o desde SharedPreferences en tiempo de ejecución.
///
/// Para compilar con URL personalizada:
/// flutter run --dart-define=DOLIBARR_BASE_URL=https://tu-dominio.com/dolibarr/api/index.php
class DolibarrService {
  /// Clave con la que se persiste la URL base en SharedPreferences.
  static const String _baseUrlKey = 'dolibarr_base_url';

  /// URL base de la API de Dolibarr.
  /// Prioridad: 1) SharedPreferences (tiempo de ejecución), 2) dart-define (tiempo de compilación), 3) valor por defecto vacío (requiere configuración).
  String _baseUrl = '';

  DolibarrService() {
    _baseUrl = const String.fromEnvironment('DOLIBARR_BASE_URL');
  }

  /// Carga la URL guardada en SharedPreferences (si existe) por sobre la
  /// configurada con --dart-define. Se invoca al iniciar la app.
  Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = saved.trim();
    }
  }

  /// Establece la URL base en tiempo de ejecución y la persiste para futuras sesiones.
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  /// Obtiene la URL base actual.
  String get baseUrl => _baseUrl;

  Map<String, String> _getHeaders(String apiKey) {
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json; charset=utf-8',
      'DOLAPIKEY': apiKey,
    };
  }

  Uri _buildUri(String endpoint) {
    if (_baseUrl.isEmpty) {
      throw StateError(
          'URL base de Dolibarr no configurada. Define DOLIBARR_BASE_URL en --dart-define o llama a setBaseUrl().');
    }
    final normalizedEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return Uri.parse('$_baseUrl/$normalizedEndpoint');
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    try {
      // Se usa bodyBytes con utf8.decode para manejo correcto de UTF-8.
      // Esto procesa bien caracteres especiales (acentos, ñ, etc.)
      return json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    } catch (_) {
      // Respaldo: intentar la decodificación estándar de la cadena
      try {
        return json.decode(response.body);
      } catch (_) {
        return response.body;
      }
    }
  }

  Future<dynamic> _request(
    String method,
    String endpoint,
    String apiKey, {
    Map<String, dynamic>? data,
  }) async {
    final uri = _buildUri(endpoint);
    late final http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _getHeaders(apiKey));
        break;
      case 'POST':
        response = await http.post(uri,
            headers: _getHeaders(apiKey),
            body: data == null ? null : json.encode(data));
        break;
      case 'PUT':
        response = await http.put(uri,
            headers: _getHeaders(apiKey),
            body: data == null ? null : json.encode(data));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: _getHeaders(apiKey));
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    final decoded = _decodeResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(
      'Dolibarr $method failed (${response.statusCode}) on $endpoint: ${decoded ?? response.body}',
    );
  }

  Future<dynamic> get(String endpoint, String apiKey) =>
      _request('GET', endpoint, apiKey);

  Future<dynamic> post(
          String endpoint, String apiKey, Map<String, dynamic> data) =>
      _request('POST', endpoint, apiKey, data: data);

  Future<dynamic> put(
          String endpoint, String apiKey, Map<String, dynamic> data) =>
      _request('PUT', endpoint, apiKey, data: data);

  Future<dynamic> delete(String endpoint, String apiKey) =>
      _request('DELETE', endpoint, apiKey);

  List<Map<String, dynamic>> _asList(dynamic response) {
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    if (response is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'result', 'members']) {
        final value = response[key];
        if (value is List) {
          return value.cast<Map<String, dynamic>>();
        }
      }
      return [response];
    }
    return const [];
  }

  // Proveedores (Third Parties con tipo proveedor)
  Future<List<Map<String, dynamic>>> getSuppliers(String apiKey) async {
    final result = await get('thirdparties?limit=100', apiKey);
    return _asList(result);
  }

  Future<Map<String, dynamic>> getSupplier(int id, String apiKey) async {
    return await get('thirdparties/$id', apiKey);
  }

  /// Busca un proveedor por RUT (idprof1/vat_number)
  Future<Map<String, dynamic>?> findSupplierByRut(String rut, String apiKey) async {
    if (rut.trim().isEmpty) return null;
    try {
      final suppliers = await getSuppliers(apiKey);
      for (final supplier in suppliers) {
        final supplierRut = supplier['idprof1']?.toString() ?? supplier['vat_number']?.toString() ?? '';
        if (supplierRut.trim().toLowerCase() == rut.trim().toLowerCase()) {
          return supplier;
        }
      }
    } catch (e) {
      print('Error buscando proveedor por RUT: $e');
    }
    return null;
  }

  /// Busca un proveedor por nombre (insensible a mayúsculas, coincidencia exacta)
  Future<Map<String, dynamic>?> findSupplierByName(String name, String apiKey) async {
    if (name.trim().isEmpty) return null;
    try {
      final suppliers = await getSuppliers(apiKey);
      final lowerName = name.trim().toLowerCase();
      for (final supplier in suppliers) {
        final supplierName = supplier['name']?.toString() ?? supplier['label']?.toString() ?? '';
        if (supplierName.trim().toLowerCase() == lowerName) {
          return supplier;
        }
      }
    } catch (e) {
      print('Error buscando proveedor por nombre: $e');
    }
    return null;
  }

  /// Busca un proveedor por RUT o nombre, retorna el primero que coincida
  Future<Map<String, dynamic>?> findSupplierByRutOrName(String? rut, String? name, String apiKey) async {
    if (rut != null && rut.trim().isNotEmpty) {
      final byRut = await findSupplierByRut(rut, apiKey);
      if (byRut != null) return byRut;
    }
    if (name != null && name.trim().isNotEmpty) {
      final byName = await findSupplierByName(name, apiKey);
      if (byName != null) return byName;
    }
    return null;
  }

  /// Obtiene las condiciones de pago de Dolibarr
  Future<List<Map<String, dynamic>>> getPaymentTerms(String apiKey) async {
    final result = await get('setup/dictionary/payment_terms?limit=100', apiKey);
    return _asList(result);
  }

  /// Obtiene las formas de pago de Dolibarr
  Future<List<Map<String, dynamic>>> getPaymentModes(String apiKey) async {
    final result = await get('setup/dictionary/payment_types?limit=100', apiKey);
    return _asList(result);
  }

  Future<int> createSupplier(Map<String, dynamic> data, String apiKey) async {
    data['type'] = 1; // 1 = proveedor
    final result = await post('thirdparties', apiKey, data);
    return _extractId(result, 'supplier');
  }

  Future<Map<String, dynamic>> updateSupplier(
      int id, Map<String, dynamic> data, String apiKey) async {
    final result = await put('thirdparties/$id', apiKey, data);
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> deleteSupplier(int id, String apiKey) async {
    await delete('thirdparties/$id', apiKey);
  }

  // Proyectos
  Future<List<Map<String, dynamic>>> getProjects(String apiKey) async {
    final result = await get('projects?limit=100', apiKey);
    return _asList(result);
  }

  Future<Map<String, dynamic>> getProject(int id, String apiKey) async {
    return await get('projects/$id', apiKey);
  }

  Future<Map<String, dynamic>> createProject(
      Map<String, dynamic> data, String apiKey) async {
    final result = await post('projects', apiKey, data);
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> updateProject(
      int id, Map<String, dynamic> data, String apiKey) async {
    final result = await put('projects/$id', apiKey, data);
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> deleteProject(int id, String apiKey) async {
    await delete('projects/$id', apiKey);
  }

  // Facturas de proveedores
  Future<List<Map<String, dynamic>>> getSupplierInvoices(String apiKey) async {
    final result = await get('supplierinvoices?limit=100', apiKey);
    return _asList(result);
  }

  Future<Map<String, dynamic>> getSupplierInvoice(int id, String apiKey) async {
    return await get('supplierinvoices/$id', apiKey);
  }

  Future<int> createSupplierInvoice(
      Map<String, dynamic> data, String apiKey) async {
    final result = await post('supplierinvoices', apiKey, data);
    return _extractId(result, 'supplier invoice');
  }

  Future<Map<String, dynamic>> updateSupplierInvoice(
      int id, Map<String, dynamic> data, String apiKey) async {
    // Extraer array_options (extrafields) si vienen en el payload
    final extrafields = data['array_options'] as Map<String, dynamic>?;
    final updateData = Map<String, dynamic>.from(data);

    // PUT principal con todos los datos
    var result = await put('supplierinvoices/$id', apiKey, updateData);

    // Si hay extrafields, forzar actualización y verificar (como en createAndFinalizeSupplierInvoice)
    if (extrafields != null && extrafields.isNotEmpty) {
      print('DolibarrService: Actualizando extrafields en factura $id: $extrafields');

      // PUT específico para extrafields (algunas versiones de Dolibarr lo requieren separado)
      await put('supplierinvoices/$id', apiKey, {'array_options': extrafields});

      // VERIFICAR: Leer la factura para confirmar que se guardó
      final verifyInvoice = await getSupplierInvoice(id, apiKey);
      final savedClasificacion = verifyInvoice['array_options']?['options_clasificacion'] ??
                                 verifyInvoice['clasificacion'];
      print('DolibarrService: Clasificación verificada tras actualización: $savedClasificacion');

      if (savedClasificacion == null || savedClasificacion.toString().isEmpty) {
        print('DolibarrService: ADVERTENCIA - Clasificación NO se guardó, reintentando...');
        // Reintento forzado
        await put('supplierinvoices/$id', apiKey, {'array_options': extrafields});

        // Verificar de nuevo
        final verifyRetry = await getSupplierInvoice(id, apiKey);
        final retryClasificacion = verifyRetry['array_options']?['options_clasificacion'] ??
                                   verifyRetry['clasificacion'];
        print('DolibarrService: Clasificación tras reintento: $retryClasificacion');
      }
    }

    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> deleteSupplierInvoice(int id, String apiKey) async {
    await delete('supplierinvoices/$id', apiKey);
  }

  /// Crea una factura de proveedor y completa el flujo contable de Dolibarr.
  ///
  /// La API no crea las lineas incluidas dentro del POST de la cabecera, por
  /// lo que se agregan una por una antes de validar y pagar la factura.
  Future<int> createAndFinalizeSupplierInvoice({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> lines,
    required String invoiceDate,
    required String apiKey,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('La factura debe tener al menos una linea.');
    }

    // Extraer array_options (extrafields) del header
    // ENVIAR EN AMBOS: POST inicial + PUT posterior (cubre ambas variantes de Dolibarr)
    final extrafields = header['array_options'] as Map<String, dynamic>?;
    final invoiceHeader = Map<String, dynamic>.from(header);
    // NO remover array_options - enviarlo en el POST inicial también

    final invoiceId = await createSupplierInvoice(invoiceHeader, apiKey);
    var stage = 'subir los productos';
    try {
      for (final line in lines) {
        await addSupplierInvoiceLine(invoiceId, line, apiKey);
      }

      // IMPORTANTE: Forzar actualización de extrafields (clasificación, etc.) DESPUÉS de crear
      // Algunas versiones de Dolibarr no los procesan en el POST inicial
      if (extrafields != null && extrafields.isNotEmpty) {
        stage = 'actualizar campos extra (clasificación, etc.)';
        print('DolibarrService: Guardando extrafields en factura $invoiceId: $extrafields');
        final updateResult = await updateSupplierInvoice(invoiceId, {'array_options': extrafields}, apiKey);
        print('DolibarrService: Resultado actualización extrafields: $updateResult');

        // VERIFICAR: Leer la factura para confirmar que se guardó
        final verifyInvoice = await getSupplierInvoice(invoiceId, apiKey);
        final savedClasificacion = verifyInvoice['array_options']?['options_clasificacion'] ??
                                   verifyInvoice['clasificacion'];
        print('DolibarrService: Clasificación verificada tras guardado: $savedClasificacion');

        if (savedClasificacion == null || savedClasificacion.toString().isEmpty) {
          print('DolibarrService: ADVERTENCIA - Clasificación NO se guardó, reintentando...');
          // Reintento forzado
          await updateSupplierInvoice(invoiceId, {'array_options': extrafields}, apiKey);
        }
      }

      stage = 'validar la factura';
      await validateSupplierInvoice(invoiceId, apiKey);
      stage = 'obtener el total validado';
      final invoice = await getSupplierInvoice(invoiceId, apiKey);
      final amount = _asDouble(invoice['total_ttc']);
      if (amount == null || amount <= 0) {
        throw StateError(
            'Dolibarr devolvio un total invalido para la factura.');
      }

      stage = 'obtener el modo de pago';
      // Usar mode_reglement_id del header si existe, sino buscar default
      final paymentModeId = invoiceHeader['mode_reglement_id'] != null
          ? _asInt(invoiceHeader['mode_reglement_id'])!
          : await _getDefaultPaymentModeId(apiKey);
      stage = 'obtener la cuenta bancaria';
      final bankAccountId = await _getDefaultBankAccountId(apiKey);
      stage = 'registrar el pago';
      await registerSupplierInvoicePayment(
        invoiceId: invoiceId,
        amount: amount,
        invoiceDate: invoiceDate,
        paymentModeId: paymentModeId,
        bankAccountId: bankAccountId,
        apiKey: apiKey,
      );
      return invoiceId;
    } catch (error, stackTrace) {
      throw SupplierInvoiceWorkflowException(
        invoiceId: invoiceId,
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> addSupplierInvoiceLine(
    int invoiceId,
    Map<String, dynamic> line,
    String apiKey,
  ) async {
    // Estos son los nombres que espera el endpoint de lineas de facturas de
    // proveedor. Los valores por defecto evitan campos PHP indefinidos en
    // instalaciones de Dolibarr mas antiguas.
    await post('supplierinvoices/$invoiceId/lines', apiKey, {
      'description': line['desc'] ?? line['description'] ?? '',
      'pu_ht': line['subprice'] ?? 0,
      'tva_tx': line['tva_tx'] ?? 0,
      'qty': line['qty'] ?? 1,
      'remise_percent': line['remise_percent'] ?? 0,
      'fk_product': line['fk_product'] ?? 0,
      'product_type': line['product_type'] ?? 0,
      'localtax1_tx': 0,
      'localtax2_tx': 0,
      'date_start': null,
      'date_end': null,
      'fk_code_ventilation': 0,
      'info_bits': 0,
      'price_base_type': 'HT',
      'rang': 0,
      'array_options': <String, dynamic>{},
      'fk_unit': null,
      'origin_id': null,
      'multicurrency_subprice': null,
      'ref_supplier': '',
      'special_code': 0,
    });
  }

  Future<void> validateSupplierInvoice(int invoiceId, String apiKey) async {
    await post('supplierinvoices/$invoiceId/validate', apiKey, {});
  }

  Future<void> registerSupplierInvoicePayment({
    required int invoiceId,
    required double amount,
    required String invoiceDate,
    required int paymentModeId,
    required String apiKey,
    required int bankAccountId,
  }) async {
    final date = DateTime.tryParse(invoiceDate) ?? DateTime.now();
    await post('supplierinvoices/$invoiceId/payments', apiKey, {
      'datepaye': date.millisecondsSinceEpoch ~/ 1000,
      'payment_mode_id': paymentModeId,
      'closepaidinvoices': 'yes',
      'accountid': bankAccountId,
      'amount': amount,
      'num_payment': '',
      'comment': 'Pago generado automáticamente al cargar la factura',
    });
  }

  Future<int> _getDefaultPaymentModeId(String apiKey) async {
    final modes =
        _asList(await get('setup/dictionary/payment_types?limit=100', apiKey));
    if (modes.isEmpty) {
      throw StateError('No hay modos de pago configurados en Dolibarr.');
    }
    const preferredCodes = ['VIR', 'TRANSFER', 'TRA', 'LIQ', 'ESP'];
    final selected = modes.firstWhere(
      (mode) => preferredCodes.contains(mode['code']?.toString().toUpperCase()),
      orElse: () => modes.first,
    );
    return _extractId(selected, 'payment mode');
  }

  Future<int> _getDefaultBankAccountId(String apiKey) async {
    try {
      final accounts = _asList(await get('bankaccounts?limit=100', apiKey));
      if (accounts.isEmpty) {
        throw StateError('No hay cuentas bancarias configuradas en Dolibarr. Se requiere al menos una cuenta bancaria para registrar pagos.');
      }

      // Referencia de la cuenta bancaria preferida. Configurable en tiempo de
      // compilación con --dart-define=DOLIBARR_BANK_ACCOUNT_REF=...
      // Si no se configura (cadena vacía), se omite la búsqueda por referencia
      // y se usa directamente la primera cuenta activa.
      final targetAccountRef =
          const String.fromEnvironment('DOLIBARR_BANK_ACCOUNT_REF');
      final Map<String, dynamic> targetAccount = {};
      if (targetAccountRef.trim().isNotEmpty) {
        targetAccount.addAll(
          accounts.firstWhere(
            (account) {
              final label = account['label']?.toString() ?? '';
              final ref = account['ref']?.toString() ?? '';
              final number = account['number']?.toString() ?? '';
              return label == targetAccountRef ||
                  ref == targetAccountRef ||
                  number == targetAccountRef;
            },
            orElse: () => <String, dynamic>{},
          ),
        );
      }

      if (targetAccount.isNotEmpty) {
        return _extractId(targetAccount, 'bank account');
      }

      // Fallback: usar la primera activa si no encuentra la específica
      final active = accounts.where((account) {
        final status = account['status'] ?? account['clos'];
        return status == null ||
            status.toString() == '1' ||
            status.toString() == '0';
      }).toList();

      return _extractId(active.isNotEmpty ? active.first : accounts.first, 'bank account');
    } catch (error) {
      if (error.toString().contains('(403)') || error.toString().contains('(404)')) {
        print('DolibarrService: No se pudo obtener cuenta bancaria (${error.toString().contains('(403)') ? 'sin permisos' : 'modulo no activo'})');
        throw StateError('No se pudo acceder al módulo de cuentas bancarias (error 403/404). Verifique permisos en Dolibarr y configure al menos una cuenta bancaria.');
      }
      rethrow;
    }
  }

  int _extractId(dynamic value, String resource) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final id = int.tryParse(value);
      if (id != null) return id;
    }
    if (value is Map) {
      for (final key in ['id', 'rowid', 'result']) {
        final id = _asInt(value[key]);
        if (id != null) return id;
      }
    }
    throw StateError('Dolibarr no devolvio el identificador de $resource.');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  // ===========================================================================
  // Notas de gastos (Expense Reports) - mdulo de gastos de Dolibarr.
  // Un "centro de gasto" se modela como una nota de gasto (expensereport) que
  // agrupa varias líneas de gasto, cada una asociada a un proyecto.
  // Dolibarr usa timestamps Unix en segundos para los campos de fecha.
  // ===========================================================================

  /// Obtiene los tipos de gasto del diccionario c_type_fees de Dolibarr.
  /// Retorna pares {id, label, code, accountancyCode?} para el selector de Tipo.
  Future<List<Map<String, dynamic>>> getExpenseTypes(String apiKey) async {
    const endpoints = [
      'setup/dictionary/c_type_fees?limit=100',
      'setup/dictionary/expense_types?limit=100',
    ];

    for (final endpoint in endpoints) {
      try {
        final result = await get(endpoint, apiKey);
        final list = _normalizeExpenseTypes(_asList(result));
        if (list.isNotEmpty) return list;
      } catch (e) {
        print('Error al obtener tipos de gasto desde $endpoint: $e');
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _normalizeExpenseTypes(
      List<Map<String, dynamic>> raw) {
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      final map = Map<String, dynamic>.from(item);
      final id = _asInt(map['id'] ?? map['rowid'] ?? map['code']);
      final label = map['label']?.toString() ?? map['libelle']?.toString() ?? '';
      // Dolibarr almacena a veces label como "CodeLabel" o "00xLabel"; limpiar.
      final cleanLabel = _cleanExpenseTypeLabel(label, map);
      if (id != null && cleanLabel.isNotEmpty) {
        list.add({
          'id': id,
          'code': map['code']?.toString() ?? '',
          'label': cleanLabel,
          'accountancyCode': map['accountancy_code']?.toString(),
        });
      }
    }
    return list;
  }

  /// Limpia el label de un tipo de gasto quitando el prefijo de código si existe.
  String _cleanExpenseTypeLabel(String label, Map map) {
    if (label.isEmpty) return '';
    final code = map['code']?.toString() ?? '';
    if (code.isNotEmpty &&
        label.toLowerCase().startsWith(code.toLowerCase())) {
      return label.substring(code.length).trim();
    }
    // Quitar prefijos numéricos tipo "00xLabel".
    final match = RegExp(r'^\d{2,4}').firstMatch(label);
    if (match != null) {
      final rest = label.substring(match.end).trim();
      return rest.isNotEmpty ? rest : label;
    }
    return label.trim();
  }

  /// Crea la cabecera de una nota de gasto (centro de gasto).
  /// El rango mensual (date_debut / date_fin) se deriva de la fecha de emisión
  /// de la boleta, according al formato de fechas de Dolibarr (segundos Unix).
  Future<int> createExpenseReport({
    required String apiKey,
    required int userId,
    required DateTime invoiceDate,
    String? ref,
  }) async {
    // Primer y último instante del mes de la boleta (rango del centro de gasto).
    final dateDebut = DateTime(invoiceDate.year, invoiceDate.month, 1, 0, 0, 0);
    final dateFin = DateTime(
        invoiceDate.year, invoiceDate.month + 1, 0, 23, 59, 59);

    final data = <String, dynamic>{
      'fk_user_author': userId,
      'fk_user_valid': userId,
      'date_debut': dateDebut.millisecondsSinceEpoch ~/ 1000,
      'date_fin': dateFin.millisecondsSinceEpoch ~/ 1000,
      'date_create': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      if (ref != null && ref.trim().isNotEmpty) 'ref': ref.trim(),
      'note_public': '',
      'note_private': '',
    };

    final result = await post('expensereports', apiKey, data);
    return _extractId(result, 'expensereport');
  }

  /// Agrega una línea de gasto a una nota de gasto existente.
  /// Cada línea puede asociarse a un proyecto (fk_project) y un tipo (fk_c_typefee).
  Future<void> addExpenseReportLine({
    required int expenseReportId,
    required String apiKey,
    required DateTime date,
    required int typeFeeId,
    required String description,
    required double qty,
    required double valueUnit, // Precio unitario neto (sin IVA) - HT
    required double vatRate, // Tasa de IVA (%)
    int? projectId,
  }) async {
    final data = <String, dynamic>{
      'date': date.millisecondsSinceEpoch ~/ 1000,
      'fk_c_typefee': typeFeeId,
      'fk_projet': projectId ?? 0,
      'comments': description,
      'qty': qty,
      'value_unit': valueUnit,
      'vatrate': vatRate,
      'vatrate_npr': 0,
      'fk_ecm_files': 0,
      // value_ht y total_ht los calcula Dolibarr en base a qty y value_unit.
    };

    await post('expensereports/$expenseReportId/lines', apiKey, data);
  }

  /// Valida (setdraft -> approve) una nota de gasto para que sea definitiva.
  Future<void> setDraftExpenseReport(int id, String apiKey) async {
    await post('expensereports/$id/setdraft', apiKey, {});
  }

  /// Aprueba una nota de gasto para que sea definitiva.
  Future<void> approveExpenseReport(int id, String apiKey) async {
    await post('expensereports/$id/approve', apiKey, {});
  }

  /// Obtiene el identificador del usuario actual (requerido para crear notas de gasto).
  Future<int> getCurrentUserId(String apiKey) async {
    for (final endpoint in ['users/me', 'users/info']) {
      try {
        final result = await get(endpoint, apiKey);
        if (result is Map) {
          final id = _asInt(result['id'] ?? result['rowid'] ?? result['user_id']);
          if (id != null && id > 0) return id;
        }
      } catch (_) {
        // Probar el siguiente endpoint.
      }
    }
    throw StateError('No se pudo obtener el identificador del usuario actual.');
  }

  /// Adjunta la imagen escaneada de la boleta a una nota de gasto.
  /// Usa el endpoint de documentos de Dolibarr (modulepart=expensereport).
  Future<void> attachExpenseReportImage({
    required int expenseReportId,
    required String filePath,
    required String fileName,
    required String apiKey,
  }) async {
    final file = http.MultipartRequest(
      'POST',
      _buildUri(
          'documents?modulepart=expensereport&file=${Uri.encodeComponent(fileName)}'),
    );
    file.headers.addAll({
      'Accept': 'application/json; charset=utf-8',
      'DOLAPIKEY': apiKey,
    });
    file.files.add(await http.MultipartFile.fromPath('file', filePath,
        filename: fileName));
    final streamed = await file.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('DolibarrService: fallo adjuntar imagen (${response.statusCode}): '
          '${response.body}');
      // No lanzar: la imagen es complementaria, el gasto ya est creado.
    } else {
      print('DolibarrService: imagen adjuntada al gasto $expenseReportId '
          '($fileName)');
    }
  }

  // Validar conexión
  Future<bool> testConnection(String apiKey) async {
    try {
      for (final endpoint in [
        'users/info',
        'users/me',
        'users/status',
        'thirdparties?limit=1',
        'projects?limit=1',
      ]) {
        try {
          await get(endpoint, apiKey);
          return true;
        } catch (_) {
          // Probar el siguiente endpoint.
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

class SupplierInvoiceWorkflowException implements Exception {
  final int invoiceId;
  final String stage;
  final Object cause;
  final StackTrace stackTrace;

  const SupplierInvoiceWorkflowException({
    required this.invoiceId,
    required this.stage,
    required this.cause,
    required this.stackTrace,
  });

  @override
  String toString() =>
      'Factura $invoiceId creada, pero fallo al $stage. ${cause.toString()}';
}

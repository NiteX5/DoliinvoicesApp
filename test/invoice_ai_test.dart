import 'package:flutter_test/flutter_test.dart';
import 'package:facturas_ssp/invoice_ai/amount_utils.dart';
import 'package:facturas_ssp/invoice_ai/date_utils.dart';
import 'package:facturas_ssp/invoice_ai/document_type_detector.dart';
import 'package:facturas_ssp/invoice_ai/models.dart';
import 'package:facturas_ssp/invoice_ai/validators.dart';

/// Construye un documento OCR a partir de líneas de texto.
/// El ancho controla las heurísticas de layout del detector.
OcrDocument _doc(double width, List<String> lineTexts) {
  final lines = lineTexts
      .map((t) => OcrLine(
            words: t
                .split(' ')
                .map((w) => OcrWord(
                      text: w,
                      left: 0,
                      top: 0,
                      right: 10,
                      bottom: 10,
                    ))
                .toList(),
            left: 0,
            top: 0,
            right: 10,
            bottom: 10,
          ))
      .toList();
  return OcrDocument(
    width: width,
    height: 1000,
    lines: lines,
    words: lines.expand((l) => l.words).toList(),
  );
}

void main() {
  group('AmountUtils.normalize', () {
    test('reconoce separadores chilenos e internacionales', () {
      expect(AmountUtils.normalize(r'$ 1.234,50'), 1234.50);
      expect(AmountUtils.normalize(r'$ 1,234.50'), 1234.50);
      expect(AmountUtils.normalize('12.50'), 12.50);
      expect(AmountUtils.normalize('12.500'), 12500);
    });

    test('devuelve null para entradas vacías o inválidas', () {
      expect(AmountUtils.normalize(null), isNull);
      expect(AmountUtils.normalize(''), isNull);
      expect(AmountUtils.normalize('   '), isNull);
      expect(AmountUtils.normalize('-'), isNull);
      expect(AmountUtils.normalize(','), isNull);
      expect(AmountUtils.normalize('.'), isNull);
    });

    test('maneja enteros, decimales y separadores de miles', () {
      expect(AmountUtils.normalize('1234'), 1234);
      expect(AmountUtils.normalize('0,5'), 0.5);
      expect(AmountUtils.normalize(r'$1.000'), 1000);
      expect(AmountUtils.normalize(r'$ 25'), 25);
      expect(AmountUtils.normalize('999.999'), 999999);
    });

    test('formatForApi siempre usa dos decimales', () {
      expect(AmountUtils.formatForApi(1234.5), '1234.50');
      expect(AmountUtils.formatForApi(0), '0.00');
    });
  });

  group('DocumentTypeDetector.detect', () {
    test('detecta una factura electrónica', () {
      final doc = _doc(1000, [
        'Factura Electrónica',
        'Razón Social: Mi Empresa S.A.',
        r'Neto $1.000.000 IVA $190.000',
        '1 Producto A 500 500',
        '2 Producto B 250 500',
        r'Total $1.190.000',
      ]);
      expect(DocumentTypeDetector.detect(doc), DocumentType.factura);
    });

    test('detecta una boleta de papel térmico', () {
      final doc = _doc(300, [
        'Boleta Electrónica',
        'Total a Pagar',
        r'Pan $500',
        r'Leche $800',
        r'Total $1.300',
        'Gracias por su compra',
      ]);
      expect(DocumentTypeDetector.detect(doc), DocumentType.boleta);
    });

    test('devuelve unknown para texto sin indicios', () {
      final doc = _doc(600, [
        'Hola mundo',
        'Esto es una prueba',
        'Texto aleatorio',
      ]);
      expect(DocumentTypeDetector.detect(doc), DocumentType.unknown);
    });
  });

  group('DateUtils.normalize', () {
    test('normaliza formato día/mes/año', () {
      expect(DateUtils.normalize('15/03/2025'), '2025-03-15');
      expect(DateUtils.normalize('15-03-25'), '2025-03-15');
    });

    test('preserva formato ISO', () {
      expect(DateUtils.normalize('2025-03-15'), '2025-03-15');
    });

    test('normaliza nombre de mes en español', () {
      expect(DateUtils.normalize('15 de Marzo 2025'), '2025-03-15');
      expect(DateUtils.normalize('31 de Diciembre 2024'), '2024-12-31');
      expect(DateUtils.normalize('1 de Enero 2023'), '2023-01-01');
    });

    test('devuelve null para entradas no válidas', () {
      expect(DateUtils.normalize(null), isNull);
      expect(DateUtils.normalize(''), isNull);
      expect(DateUtils.normalize('texto inválido'), isNull);
      expect(DateUtils.normalize('12'), isNull);
      expect(DateUtils.normalize('31/12'), isNull);
    });
  });

  group('InvoiceValidators', () {
    test('conserva totales impresos cuando las líneas no cuadran (factura)', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
          header: InvoiceHeader(neto: 1000, iva: 190, total: 1200),
          items: [
            InvoiceItem(
              descripcion: 'Producto con descuento',
              cantidad: 2,
              precioUnitario: 600,
              totalLinea: 1000,
              tasaIva: 19,
            ),
          ],
        ),
        DocumentType.factura,
      );

      expect(result.header.total, 1200);
      expect(result.items.single.totalLinea, 1000);
      expect(result.items.single.subtotal, 1200);
    });

    test('deriva solo el impuesto faltante desde neto y total impresos (factura)', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
            header: InvoiceHeader(neto: 1000, total: 1190), items: []),
        DocumentType.factura,
      );

      expect(result.header.iva, 190);
      expect(result.header.total, 1190);
    });

    test('filtra etiquetas de documento que no son productos', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
          header: InvoiceHeader(),
          items: [
            InvoiceItem(descripcion: 'IVA (19%)', totalLinea: 190),
            InvoiceItem(descripcion: 'Nota de venta', totalLinea: 1000),
            InvoiceItem(
                descripcion: 'Tubo acero', cantidad: 2, totalLinea: 1000),
          ],
        ),
        DocumentType.factura,
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.descripcion, 'Tubo acero');
    });

    test('boleta: no inventa neto/iva si solo hay total', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
          header: InvoiceHeader(total: 1300),
          items: [
            InvoiceItem(descripcion: 'Pan', totalLinea: 500),
            InvoiceItem(descripcion: 'Leche', totalLinea: 800),
          ],
        ),
        DocumentType.boleta,
      );

      expect(result.header.total, 1300);
      expect(result.header.neto, isNull);
      expect(result.header.iva, isNull);
    });

    test('boleta: conserva líneas sin cantidad/precio (solo descripción + total)', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
          header: InvoiceHeader(total: 500),
          items: [InvoiceItem(descripcion: 'Pan', totalLinea: 500)],
        ),
        DocumentType.boleta,
      );

      expect(result.items.single.cantidad, isNull);
      expect(result.items.single.precioUnitario, isNull);
      expect(result.items.single.totalLinea, 500);
      expect(result.items.single.priceIncludesVat, isTrue);
    });
  });
}

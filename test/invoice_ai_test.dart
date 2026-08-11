import 'package:flutter_test/flutter_test.dart';
import 'package:facturas_ssp/invoice_ai/amount_utils.dart';
import 'package:facturas_ssp/invoice_ai/models.dart';
import 'package:facturas_ssp/invoice_ai/validators.dart';

void main() {
  group('AmountUtils.normalize', () {
    test('recognizes Chilean and international separators', () {
      expect(AmountUtils.normalize(r'$ 1.234,50'), 1234.50);
      expect(AmountUtils.normalize(r'$ 1,234.50'), 1234.50);
      expect(AmountUtils.normalize('12.50'), 12.50);
      expect(AmountUtils.normalize('12.500'), 12500);
    });
  });

  group('InvoiceValidators', () {
    test('keeps printed totals when lines do not reconcile (factura)', () {
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

    test('derives only missing tax from printed net and total (factura)', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
            header: InvoiceHeader(neto: 1000, total: 1190), items: []),
        DocumentType.factura,
      );

      expect(result.header.iva, 190);
      expect(result.header.total, 1190);
    });

    test('filters document labels that are not products', () {
      final result = InvoiceValidators.validateAndFix(
        InvoiceResult(
          header: InvoiceHeader(),
          items: [
            InvoiceItem(descripcion: 'IVA (19%)', totalLinea: 190),
            InvoiceItem(descripcion: 'Nota de venta', totalLinea: 1000),
            InvoiceItem(descripcion: 'Tubo acero', cantidad: 2, totalLinea: 1000),
          ],
        ),
        DocumentType.factura,
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.descripcion, 'Tubo acero');
    });
  });
}

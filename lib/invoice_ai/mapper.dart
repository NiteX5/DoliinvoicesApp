import 'models.dart';
import 'amount_utils.dart';
import 'constants.dart';

class DolibarrMapper {
  static DolibarrInvoiceResult toDolibarr(InvoiceResult invoice, {
    int? condReglementId,
    String? dateLimReglement,
    int? modeReglementId,
  }) {
    final items = invoice.items
        .where((item) =>
            item.descripcion != null &&
            (item.totalLinea != null || item.precioUnitario != null))
        .map((item) => DolibarrInvoiceItem(
              description: item.descripcion!,
              qty: item.cantidad ?? 1,
              subprice: AmountUtils.formatForApi(item.precioUnitario ??
                  (item.totalLinea! / (item.cantidad ?? 1))),
              totalHt: AmountUtils.formatForApi(item.totalLinea ??
                  (item.precioUnitario! *
                      (item.cantidad ?? 1) *
                      (1 - (item.descuento ?? 0) / 100))),
              tvaTx: item.tasaIva ?? InvoiceAiConstants.defaultIvaTx,
              remisePercent: item.descuento ?? 0,
              priceIncludesVat: item.priceIncludesVat ?? false,
            ))
        .toList();

    final totalHt = invoice.header.neto != null
        ? AmountUtils.formatForApi(invoice.header.neto!)
        : null;
    final totalTva = invoice.header.iva != null
        ? AmountUtils.formatForApi(invoice.header.iva!)
        : null;
    final totalTtc = invoice.header.total != null
        ? AmountUtils.formatForApi(invoice.header.total!)
        : null;

    print(
        'DolibarrMapper.toDolibarr: totalHt=$totalHt, totalTva=$totalTva, totalTtc=$totalTtc, items count=${items.length}');

    // Usar fecha de factura como fecha límite de pago por defecto si no se proporciona
    final resolvedDateLimReglement = dateLimReglement ?? invoice.header.fecha;

    return DolibarrInvoiceResult(
      refSupplier: invoice.header.numeroDocumento,
      date: invoice.header.fecha,
      supplier: invoice.header.proveedor,
      supplierRut: invoice.header.rut,
      supplierGiro: invoice.header.giro,
      supplierDireccion: invoice.header.direccion,
      supplierCiudad: invoice.header.ciudad,
      // Nota: email y teléfono no existen aún en InvoiceHeader;
      // podrían agregarse al modelo si se necesitan.
      totalTtc: totalTtc,
      totalHt: totalHt,
      totalTva: totalTva,
      condReglementId: condReglementId,
      dateLimReglement: resolvedDateLimReglement,
      modeReglementId: modeReglementId,
      items: items,
    );
  }
}

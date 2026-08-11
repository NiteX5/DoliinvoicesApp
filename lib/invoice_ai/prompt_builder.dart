import 'dart:convert';
import 'models.dart';

class PromptBuilder {
  static const String promptVersion = '2.1';

  static String buildPrompt(OcrDocument document, DocumentType documentType) {
    final jsonString = jsonEncode(_documentToJson(document));
    final plainText = document.lines.map((line) => line.text).join('\n');

    final isBoleta = documentType == DocumentType.boleta;
    final isFactura = documentType == DocumentType.factura;
    final isThermalPaper = document.width < 400; // Heurística papel térmico

    return '''
Eres un extractor de datos especializado en facturas y boletas tributarias chilenas.
Clasifica el texto OCR y devuelve exclusivamente un JSON válido. Tu respuesta debe comenzar con { y terminar con }; no incluyas Markdown, explicaciones ni texto adicional.

DOCUMENTO OCR ESTRUCTURADO (palabras con coordenadas para alineación de columnas):
$jsonString

TEXTO OCR RECONSTRUIDO (ordenado de arriba hacia abajo):
"""
$plainText
"""

METADATOS:
- prompt_version: $promptVersion
- document_width_px: ${document.width.toStringAsFixed(0)}
- document_height_px: ${document.height.toStringAsFixed(0)}
- is_thermal_paper: $isThermalPaper
- detected_type: ${isBoleta ? 'boleta' : isFactura ? 'factura' : 'unknown'}

REGLAS GENERALES:
1. Usa el texto reconstruido para comprender el documento y las COORDENADAS X (left, centerX, right) de cada palabra para reunir columnas de la misma fila.
2. ALINEACIÓN DE COLUMNAS: Las palabras con centerX similar (± 25px) pertenecen a la misma columna vertical. Identifica columnas por patrones:
   - Columna CANTIDAD: números enteros pequeños (1-999) alineados a la izquierda
   - Columna PRECIO UNITARIO: números con decimales alineados a la derecha
   - Columna TOTAL LÍNEA: números más grandes, a la derecha del precio
   - Columna DESCRIPCIÓN: texto a la izquierda de los números
3. "productos" contiene SOLO bienes o servicios vendidos/comprados. Excluye siempre encabezados, pie de página, notas de venta, datos del emisor/receptor, RUT, direcciones, teléfonos, fechas, formas de pago, subtotales, neto, IVA, total, descuentos globales, flete e impuestos. Esos datos pertenecen a header o se ignoran; NUNCA son productos.
4. No inventes datos. Si no encuentras un campo, usa null o [] para productos.
5. Los montos son números, nunca strings. Conserva los importes impresos y no calcules montos para completar una fila.
6. precioUnitario, subtotal y totalLinea son valores netos sin IVA. Si el documento solo muestra valores con IVA incluido y no permite obtener el neto, deja esos valores en null.
7. subtotal es el neto antes de descuento; totalLinea es el neto final de la fila. descuento es porcentaje (0 a 100) y tasaIva es porcentaje (19 o 0), no montos.
8. Los totales del header son los impresos en el documento. No los reemplaces por la suma de productos.
9. Identifica la cantidad real de cada producto. No uses 1 por defecto si la fila contiene una cantidad en otra columna. Si no es visible, usa null.
10. fecha es exclusivamente la fecha de emisión/facturación visible junto a "Fecha", "Emisión" o equivalente; nunca una dirección ni una fecha de vencimiento. Usa YYYY-MM-DD. numeroDocumento es el folio/Ref. Proveedor.
11. RUT chileno: formato XX.XXX.XXX-X (ej: 76.123.456-7). Busca en todo el documento.
12. Responde exactamente con esta estructura:
{
  "header": {
    "tipoDocumento": "${isBoleta ? '"boleta"' : isFactura ? '"factura"' : '"factura" | "boleta" | null'}",
    "numeroDocumento": string | null,
    "fecha": string | null,
    "fechaVencimiento": string | null,
    "proveedor": string | null,
    "rut": string | null,
    "giro": string | null,
    "direccion": string | null,
    "ciudad": string | null,
    "moneda": string | null,
    "neto": number | null,
    "exento": number | null,
    "iva": number | null,
    "otrosImpuestos": number | null,
    "total": number | null
  },
  "productos": [
    {
      "tipoLinea": "producto",
      "codigo": string | null,
      "descripcion": string | null,
      "cantidad": number | null,
      "unidad": string | null,
      "precioUnitario": number | null,
      "descuento": number | null,
      "subtotal": number | null,
      "iva": number | null,
      "tasaIva": number | null,
      "totalLinea": number | null,
      "priceIncludesVat": boolean | null
    }
  ]
}

${isBoleta ? _boletaSpecificRules(isThermalPaper) : isFactura ? _facturaSpecificRules() : _generalRules()}
''';
  }

  static String _boletaSpecificRules(bool isThermalPaper) {
    final thermalNote = isThermalPaper
        ? '''
NOTA: Documento detectado como papel térmico (ancho < 400px).
- Líneas muy cortas, una columna visual.
- Formato típico: "2 x PRODUCTO ... \$3.500" o "PRODUCTO ... \$3.500"
- Cantidad al inicio: "2 x ", "2x ", "Cant 2", "2 und"
- NO hay desglose Neto/IVA/Exento. Solo "Total" o "Total a pagar".
- Items: descripción + total línea. cantidad/precioUnitario/subtotal → null si no se ven claros.
'''
        : '';
    return '''
REGLAS ESPECÍFICAS PARA BOLETAS (DTE Tipo 39):
- Las boletas NO suelen tener desglose de Neto/IVA/Exento. Generalmente SOLO muestran "Total" o "Total a pagar".
- NO busques ni inventes campos "neto", "iva", "exento" en el header si no aparecen explícitamente. Déjalos en null.
- Los items en boletas son simples: descripción + total línea. Rara vez tienen cantidad, precio unitario, descuento o subtotal separados.
- Para items: extrae "descripcion" (texto antes del monto) y "totalLinea" (el monto final). cantidad, precioUnitario, subtotal -> null si no se ven claros.
- El proveedor puede aparecer como "Giro", "Razón Social", o solo nombre comercial. Busca RUT del emisor.
- Palabras clave típicas boleta: "boleta", "boleta electrónica", "total a pagar", "monto total", "gracias por su compra", "no válida como factura", "conservar para garantía".
$thermalNote
''';
  }

  static String _facturaSpecificRules() {
    return '''
REGLAS ESPECÍFICAS PARA FACTURAS (DTE Tipo 33, 46, 56, 61):
- Las facturas TIENEN desglose: busca explícitamente "Neto", "Neto Afecto", "Exento", "IVA", "Total". Extrae los tres (neto, iva, exento) si están.
- Los items tienen estructura tabular: Código, Descripción, Cantidad, Unidad, Precio Unitario, Descuento%, Subtotal, IVA, Total Línea.
- USA COORDENADAS X para alinear columnas. Una fila = palabras con centerX alineados verticalmente (±25px).
- Header completo: Razón Social emisor + receptor, RUT ambos, Dirección ambos, Giro, Ciudad, Forma pago, Vencimiento, OC, Vendedor, Sucursal.
- Palabras clave típicas factura: "factura", "factura electrónica", "razón social", "neto afecto", "iva", "subtotal", "descuento global", "orden de compra", "fecha vencimiento".
''';
  }

  static String _generalRules() {
    return '''
REGLAS GENERALES (tipo no detectado con confianza):
- Aplica heurísticas: si ves desglose neto/iva/exento -> factura; si solo "total" -> boleta.
- Si hay tabla con columnas claras (números alineados en X) -> factura; si líneas simples descripción+monto -> boleta.
''';
  }

  static Map<String, dynamic> _documentToJson(OcrDocument document) {
    return {
      'document': {
        'width': document.width,
        'height': document.height,
        // Palabras con coordenadas completas para alineación de columnas en Gemini
        'words': document.words
            .map((word) => {
                  'text': word.text,
                  'left': word.left,
                  'centerX': word.centerX,
                  'right': word.right,
                  'top': word.top,
                  'bottom': word.bottom,
                  'width': word.width,
                  'height': word.height,
                })
            .toList(),
        // Líneas agrupadas (para contexto de lectura secuencial)
        'lines': document.lines
            .map((line) => {
                  'text': line.text,
                  'left': line.left,
                  'centerX': line.centerX,
                  'right': line.right,
                  'top': line.top,
                  'bottom': line.bottom,
                  'width': line.width,
                  'height': line.height,
                })
            .toList(),
      },
    };
  }
}
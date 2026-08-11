<div align="center">

# 📄 Facturas SSP

### Gestión de facturas de proveedores con **OCR + IA** y sincronización a **Dolibarr ERP**

`Flutter` · `ML Kit` · `Google Gemini` · `Dolibarr REST API`

[![Flutter](https://img.shields.io/badge/Flutter-3.44.6-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Plataforma](https://img.shields.io/badge/Plataforma-Android-3DDC84?logo=android&logoColor=white)]()
[![Estado](https://img.shields.io/badge/Estado-En%20desarrollo-orange)]()
[![Licencia](https://img.shields.io/badge/Licencia-MIT-green.svg)](LICENSE)

---

**Fotografía o escanea una factura → la app extrae los datos con IA → crea la factura validada y pagada en Dolibarr con un solo toque.**

</div>

---

## ✨ Características

| | |
|---|---|
| 🔐 **Login seguro** | Sesión con la API Key de Dolibarr (no hay claves por defecto ni hardcodeadas). |
| 📷 **OCR con ML Kit** | Captura por cámara o galería y reconocimiento de texto con agrupación inteligente de líneas (clustering 1D). |
| 🤖 **Extracción con Gemini** | El texto OCR se envía a Gemini con un **esquema JSON estricto** para obtener proveedor, RUT, fechas, montos e ítems de forma estructurada. |
| 🧾 **Detección Factura vs Boleta** | Heurística por palabras clave y layout (papel térmico vs carta). |
| ✅ **Validación inteligente** | Se cruzan los totales impresos contra la suma de ítems (±5%), se derivan montos faltantes y se detectan ítems duplicados. |
| 📦 **CRUD completo** | Facturas de proveedores, proveedores y proyectos vinculados. |
| 🧮 **Flujo contable Dolibarr** | Crea cabecera + líneas + extrafields, valida la factura y registra el pago automáticamente. |
| 🎨 **UI Material 3** | Diseño moderno y reutilizable (tarjetas, búsqueda, filtros, esqueletos de carga). |

---

## 🧠 ¿Cómo funciona?

```
 ┌────────────┐     ┌──────────────┐     ┌──────────────────────┐
 │  Cámara /   │     │   ML Kit     │     │  Gemini API          │
 │  Galería    │ ──▶ │  (OCR)       │ ──▶ │  generateContent     │
 └────────────┘     └──────────────┘     │  + JSON schema       │
        Imagen        Texto + coordenadas └──────────────────────┘
                                                     │
                                                     ▼
 ┌────────────┐     ┌──────────────┐     ┌──────────────────────┐
 │  Dolibarr  │ ◀── │  Validador   │ ◀── │  Parser              │
 │  REST API  │     │  + Mapper    │     │  (respuesta JSON)    │
 └────────────┘     └──────────────┘     └──────────────────────┘
   Factura creada      Totales cruzados
   y pagada            y ítems corregidos
```

1. **OCR**: se extrae el texto del documento junto con las coordenadas de cada palabra.
2. **Prompt**: se construye un prompt con el texto y las coordenadas para que Gemini alinee columnas.
3. **Gemini**: devuelve un JSON estructurado (header, ítems, montos) forzado por esquema.
4. **Validación**: se corrigen totales, cantidades y precios; se detectan duplicados y etiquetas que no son productos.
5. **Dolibarr**: se crea la factura con sus líneas, clasificación, validación y registro de pago.

> 💡 Si Gemini no responde, existe un **modo de extracción local** (`local_fallback.dart`) que intenta extraer los datos sin IA.

---

## 📋 Requisitos previos

- Flutter SDK **>= 3.0.0** (probado con Flutter 3.44 / Dart 3.12).
- Dispositivo o emulador **Android** (mínimo Android 5.0 / API 21).
- Instalación de **Dolibarr** con la **API REST** habilitada y un usuario con clave de API.
- **API Key de Google Gemini** (Google AI Studio).

---

## 🚀 Instalación

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio> facturas_ssp
cd facturas_ssp

# 2. Instalar dependencias
flutter pub get
```

---

## ⚙️ Configuración

### 1. Variables de entorno (tiempo de compilación)

La app lee su configuración con `--dart-define`. Copia el ejemplo y rellena tus valores:

```bash
cp .env.example .env   # solo documentación — los valores se pasan con --dart-define
```

| Variable | Descripción | Obligatoria |
|---|---|---|
| `DOLIBARR_BASE_URL` | URL base de la API de Dolibarr (ej. `https://tu-dominio.com/dolibarr/api/index.php`). | ✅ |
| `GEMINI_API_KEY` | API Key de Google Gemini para la extracción con IA. | ✅* |
| `DOLIBARR_BANK_ACCOUNT_REF` | Referencia de la cuenta bancaria preferida para pagos. Vacío = primera activa. | ❌ |

\* Obligatoria solo si se usa la captura automática de facturas con IA.

### 2. `applicationId` de Android

Crea `android/local.properties` (está en `.gitignore`, no se sube al repo):

```properties
flutter.applicationId=com.tuempresa.app
```

Si no se define, la app usa el valor por defecto `com.facturas_ssp.app`.

### 3. API Key de Dolibarr

1. En Dolibarr: **Inicio → Configuración → API**, habilita la API REST.
2. Genera la **clave de API** de tu usuario.
3. Ingresa esa clave en la pantalla de **login** de la app (se valida contra Dolibarr antes de entrar).

---

## ▶️ Ejecución

```bash
# Con todas las variables
flutter run \
  --dart-define=DOLIBARR_BASE_URL=https://tu-dominio.com/dolibarr/api/index.php \
  --dart-define=GEMINI_API_KEY=tu_api_key_gemini \
  --dart-define=DOLIBARR_BANK_ACCOUNT_REF=REF_BANCO
```

```bash
# Compilar APK
flutter build apk --debug
```

---

## 🏗️ Estructura principal

```
lib/
├── main.dart                        # Punto de entrada y providers
├── models/                          # Modelos (proveedor, proyecto, factura, producto)
├── services/
│   ├── auth_service.dart            # Sesión con API Key de Dolibarr
│   └── dolibarr_service.dart        # Cliente REST de Dolibarr
├── invoice_ai/                      # 🧠 Pipeline OCR + IA
│   ├── ocr_service.dart             # OCR ML Kit (clustering de líneas)
│   ├── gemini_client.dart           # Cliente REST de Gemini (JSON schema)
│   ├── prompt_builder.dart          # Prompt con coordenadas de columnas
│   ├── parser.dart                  # Parsea respuesta estructurada
│   ├── validators.dart              # Valida/corrige totales e ítems
│   ├── mapper.dart                  # Mapea a formato Dolibarr
│   ├── document_type_detector.dart  # Detecta Factura vs Boleta
│   └── local_fallback.dart          # Extracción local sin IA
├── screens/                         # Pantallas (login, home, listas, formularios)
└── widgets/shared/                  # Widgets reutilizables (Material 3)
```

---

## 🔗 Integración con Dolibarr

La app usa la **API REST** de Dolibarr con el header `DOLAPIKEY`. Endpoints principales:

| Operación | Endpoint |
|---|---|
| Proveedores (CRUD) | `/thirdparties` (+ `/{id}`) |
| Proyectos (CRUD) | `/projects` (+ `/{id}`) |
| Facturas proveedor (CRUD) | `/supplierinvoices` (+ `/{id}`) |
| Agregar línea | `/supplierinvoices/{id}/lines` |
| Validar factura | `/supplierinvoices/{id}/validate` |
| Registrar pago | `/supplierinvoices/{id}/payments` |
| Condiciones / formas de pago | `/setup/dictionary/payment_terms`, `/payment_types` |
| Cuentas bancarias | `/bankaccounts` |

**Flujo de creación** (`createAndFinalizeSupplierInvoice`):

```
1. POST cabecera de factura (proveedor, fechas, condiciones, forma de pago)
2. POST cada línea   →  /supplierinvoices/{id}/lines
3. PUT array_options  →  extrafields (ej. options_clasificacion) + verificación
4. POST validate      →  valida la factura
5. POST payments      →  registra el pago (cuenta configurada o primera activa)
```

> ℹ️ La URL base se resuelve con esta prioridad: **SharedPreferences** → **`DOLIBARR_BASE_URL`** → cadena vacía (requiere configuración).

---

## 🔐 Seguridad

- ✅ **Sin API keys por defecto ni hardcodeadas** — la de Dolibarr se pide en el login; la de Gemini se inyecta con `--dart-define`.
- ✅ **`applicationId` de Android parametrizado** en `local.properties` (no se expone el identificador real de producción).
- ✅ **Cuenta bancaria parametrizada** con `DOLIBARR_BANK_ACCOUNT_REF`.
- ✅ **`.env`, `local.properties` y `.claude/settings*.json` están en `.gitignore`**.
- ✅ **Auditoría de secretos** realizada antes del commit (sin claves ni tokens en el repositorio).

---

## 🧪 Testing y calidad

```bash
flutter analyze   # 0 errores · 0 warnings
flutter test      # cubre normalización de montos y validadores de facturas/boletas
```

---

## 📄 Licencia

Este proyecto está bajo la licencia **MIT**. Ver el archivo [LICENSE](LICENSE) para más detalles.

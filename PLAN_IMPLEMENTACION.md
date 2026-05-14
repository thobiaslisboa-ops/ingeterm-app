# PLAN DE IMPLEMENTACIÓN - Mejoras de Mantenimiento

## 📋 Resumen de lo Implementado

Se han creado **6 nuevos componentes principales** pensados como un mantenedor profesional:

### ✅ Creados

1. **`maintenance_extended_model.dart`**
   - Modelo `MaintenanceRecordExtended` con información completa
   - Modelo `ComponentReplacement` para cambios de componentes
   - Modelo `PressureReading` para lecturas de presión
   - Enums: `MaintenanceTypeExtended`, `TestResult`

2. **`maintenance_timeline.dart`** - Widget
   - Timeline visual de mantenciones
   - Muestra tipo (Preventivo/Correctivo/Urgente)
   - Información del técnico
   - Reemplazos realizados
   - Fotos y próxima mantención

3. **`maintenance_detail_screen.dart`** - Pantalla
   - Vista completa de un mantenimiento
   - Trabajo realizado, problemas, soluciones
   - Galería de fotos
   - Lecturas de presión
   - Botón de generar reporte

4. **`component_replacement_dialog.dart`** - Widget
   - Dialog para registrar cambio de componente
   - Captura: serial viejo/nuevo, modelo, razón
   - Resultado de prueba funcional
   - Notas del técnico

5. **`report_generator.dart`** - Servicio
   - Genera reportes en texto (base para PDF)
   - Reporte individual de mantenimiento
   - Resumen de período
   - Histórico de cambios de componente

6. **`smart_sync_service.dart`** - Servicio
   - Monitoreo de conectividad
   - Estados: Synced/Syncing/Offline/Error
   - Widget `SyncStatusIndicator`
   - Queue de sincronización pendiente

7. **`maintenance_kpi_dashboard.dart`** - Widget
   - Dashboard de estadísticas
   - KPIs principales (total, últimos 30 días, etc)
   - Análisis de efectividad
   - Tipos de mantenimiento
   - Insights automáticos

### 📚 Documentación Creada

- **`MEJORAS_MANTENIMIENTO.md`** - Plan completo de mejoras
- **`GUIA_MANTENEDORES.md`** - Manual de usuario para técnicos

---

## 🔧 PRÓXIMOS PASOS DE INTEGRACIÓN

### FASE 1: Integración en valve_detail_screen.dart (2-3 horas)

**Objetivo:** Ver historial de mantenciones de una válvula

1. Importar:
   ```dart
   import '../models/maintenance_extended_model.dart';
   import '../widgets/maintenance_timeline.dart';
   import '../screens/maintenance_detail_screen.dart';
   ```

2. En la pestaña "Información":
   ```dart
   FutureBuilder<List<MaintenanceRecordExtended>>(
     future: _fetchValveMaintenances(),
     builder: (context, snapshot) {
       if (snapshot.hasData) {
         return MaintenanceTimeline(
           maintenances: snapshot.data!,
           onItemTap: () {
             Navigator.push(
               context,
               SmoothPageTransition(
                 page: MaintenanceDetailScreen(
                   maintenance: maintenance,
                 ),
               ),
             );
           },
         );
       }
       return const CircularProgressIndicator();
     },
   )
   ```

---

### FASE 2: Agregar Botón "Registrar Cambio de Válvula" (1-2 horas)

**Ubicación:** `valve_detail_screen.dart` - En el AppBar

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.swap_horiz),
    onPressed: () {
      showDialog(
        context: context,
        builder: (_) => ComponentReplacementDialog(
          componentName: 'Válvula ${widget.valveName}',
          currentSerialNumber: valveData['serialNumber'],
          currentModel: valveData['model'],
          onReplacementRecorded: (replacement) {
            // Guardar en Firestore
            _saveComponentReplacement(replacement);
          },
        ),
      );
    },
    tooltip: 'Registrar cambio de válvula',
  ),
],
```

---

### FASE 3: Integrar Dashboard de KPIs (2-3 horas)

**Ubicación:** Nueva pestaña en `equipment_detail_screen.dart`

1. Cambiar TabBar de 4 a 5 pestañas:
   ```dart
   tabs: const [
     Tab(icon: Icon(Icons.info), text: 'Información'),
     Tab(icon: Icon(Icons.water_drop), text: 'Pruebas'),
     Tab(icon: Icon(Icons.lock), text: 'Válvulas'),
     Tab(icon: Icon(Icons.build), text: 'Componentes'),
     Tab(icon: Icon(Icons.bar_chart), text: 'Dashboard'),
   ],
   ```

2. Agregar en TabBarView:
   ```dart
   MaintenanceKPIDashboard(
     allMaintenances: _fetchAllMaintenances(),
     equipmentName: widget.equipmentName,
   )
   ```

---

### FASE 4: Sincronización Inteligente (2-3 horas)

**Ubicación:** `main.dart` - En el MaterialApp

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await Firebase.initializeApp();
  final syncService = SmartSyncService();
  
  runApp(MaintenanceApp(syncService: syncService));
}

class MaintenanceApp extends StatelessWidget {
  final SmartSyncService syncService;
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Tu app content
            SliverToBoxAdapter(
              child: SyncStatusIndicator(syncService: syncService),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### FASE 5: Generación de Reportes PDF (3-4 horas)

**Ubicación:** Crear `lib/services/pdf_generator.dart`

Usar librería `pdf` de pub.dev:

```yaml
dependencies:
  pdf: ^3.10.0
  printing: ^5.10.0
```

Función:
```dart
Future<void> generatePDF(MaintenanceRecordExtended maintenance) async {
  final pdf = pw.Document();
  final textReport = MaintenanceReportGenerator.generateTextReport(...);
  
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Text(textReport),
    ),
  );
  
  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}
```

---

### FASE 6: Ampliación de Registro de Mantención (2-3 horas)

**Ubicación:** `valve_detail_screen.dart` - En `_openMaintenanceDialog`

Agregar campos:
```dart
// Tipo de mantenimiento
DropdownButtonFormField<MaintenanceTypeExtended>(
  items: MaintenanceTypeExtended.values.map(...).toList(),
  onChanged: (value) {
    setState(() => selectedType = value!);
  },
)

// Próxima mantención sugerida
DatePickerField(
  label: 'Próxima mantención',
  initialDate: DateTime.now().add(Duration(days: 180)),
)

// Componentes reemplazados (lista)
if (replacements.isNotEmpty)
  ListView.builder(
    itemCount: replacements.length,
    itemBuilder: (_, i) => buildReplacementCard(replacements[i]),
  )
```

---

## 📦 DEPENDENCIAS A AGREGAR

En `pubspec.yaml`:

```yaml
dependencies:
  # Reportes
  pdf: ^3.10.0
  printing: ^5.10.0
  
  # Sincronización
  connectivity_plus: ^5.0.0  # Ya existe
  
  # UUID para IDs únicos
  uuid: ^4.0.0
  
  # Caché local
  hive: ^2.2.0
  hive_flutter: ^1.1.0
  
  # Compresión de imágenes
  flutter_image_compress: ^4.1.0  # Ya existe
  
  # Intl para fechas
  intl: ^0.19.0  # Ya existe
```

Ejecutar:
```bash
flutter pub get
dart run build_runner build  # Para Hive
```

---

## 🗄️ CAMBIOS EN ESTRUCTURA DE FIRESTORE

Necesitas actualizar estructura de mantenciones existentes:

**Antes:**
```
clients/{clientId}/equipments/{equipmentId}/valves/{valveId}/maintenances/{mainId}
├─ date
├─ notes
├─ setPoint
└─ cutOff
```

**Después (Compatible):**
```
clients/{clientId}/equipments/{equipmentId}/valves/{valveId}/maintenances/{mainId}
├─ dateTime ← (Renombar de "date")
├─ type ← NEW (preventivo/correctivo/urgente)
├─ description ← NEW
├─ problemsFound ← NEW
├─ solutionApplied ← NEW
├─ technicianName ← NEW
├─ technicianId ← NEW
├─ durationHours ← NEW (opcional)
├─ nextScheduledMaintenance ← NEW (DateTime)
├─ replacements ← NEW (Array de ComponentReplacement)
│  ├─ id
│  ├─ componentName
│  ├─ oldSerialNumber
│  ├─ newSerialNumber
│  ├─ oldModel
│  ├─ newModel
│  ├─ replacementReason
│  ├─ replacementDateTime
│  ├─ functionalTest
│  ├─ photoUrls
│  └─ notes
├─ photoUrls
├─ pressureReadings ← NEW (Array)
│  ├─ timestamp
│  ├─ pressure
│  └─ temperature
├─ notes ← RENOMBRAR a "additionalNotes"
├─ setPoint ← Mover a pressureReadings
└─ cutOff ← Mover a pressureReadings
```

**Migration Script (Funcionales Cloud):**
```javascript
exports.migrateMaintenanceRecords = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  
  const snapshot = await db.collectionGroup('maintenances').get();
  
  const batch = db.batch();
  snapshot.docs.forEach(doc => {
    batch.update(doc.ref, {
      type: 'correctivo', // Valor por defecto
      description: '',
      problemsFound: doc.data().notes || '',
      solutionApplied: '',
      technicianName: 'Técnico Anterior',
      replacements: [],
      pressureReadings: [{
        timestamp: doc.data().date,
        pressure: parseFloat(doc.data().setPoint) || 0,
        temperature: null,
      }],
    });
  });
  
  await batch.commit();
  res.send('Migration completed');
});
```

---

## 🧪 TESTING

Crear tests para nuevos modelos:

```dart
// test/models_test.dart
void main() {
  test('MaintenanceRecordExtended creation', () {
    final record = MaintenanceRecordExtended(
      id: '1',
      clientId: 'client1',
      equipmentId: 'eq1',
      dateTime: DateTime.now(),
      technicianName: 'Juan',
      technicianId: 'tech1',
      type: MaintenanceTypeExtended.preventivo,
      description: 'Test',
      problemsFound: '',
      solutionApplied: '',
      replacements: [],
      photoUrls: [],
      pressureReadings: [],
    );
    
    expect(record.type.label, 'Preventivo');
  });
}
```

---

## 📊 ORDEN DE IMPLEMENTACIÓN RECOMENDADO

| # | Tarea | Dependencias | Tiempo | Prioridad |
|---|-------|-------------|--------|-----------|
| 1 | Fase 1 - Historial en válvulas | MaintenanceTimeline | 2h | 🔴 CRÍTICA |
| 2 | Fase 2 - Botón Cambio | ComponentReplacementDialog | 1.5h | 🔴 CRÍTICA |
| 3 | Fase 3 - Dashboard KPI | MaintenanceKPIDashboard | 3h | 🟠 IMPORTANTE |
| 4 | Fase 4 - Sync Service | SmartSyncService | 2h | 🟡 NORMAL |
| 5 | Fase 5 - Reportes PDF | ReportGenerator + PDF lib | 4h | 🟡 NORMAL |
| 6 | Fase 6 - Ampliación registro | Todos anteriores | 3h | 🟡 NORMAL |

**Total Estimado:** 15-16 horas de desarrollo

---

## 🎯 OBJETIVO FINAL

✅ Aplicación que:
- Funciona sin internet en plantas aisladas
- Registra cada acción con detalle
- Genera reportes profesionales
- Muestra histórico completo
- KPIs para tomar decisiones
- Sincronización automática
- Pensada como un mantenedor profesional

Es la **mejor aplicación de mantenimiento para Ingeterm** 🏆

¿Empezamos con Fase 1?


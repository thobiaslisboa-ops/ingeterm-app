# GUÍA DE USO - Aplicación de Mantenimiento Ingeterm

## 📱 Visión General

Esta aplicación está diseñada por y para **ingenieros y técnicos de mantenimiento**, pensando en los desafíos reales del trabajo en plantas industriales.

### ✨ Características Principales

1. **Offline First** - Funciona sin internet 🌐
2. **Historial Completo** - Ve qué pasó antes ⏰
3. **Cambio de Componentes** - Registra reemplazos 📦
4. **Reportes Profesionales** - Entrega documentación 📄
5. **Sincronización Automática** - Conecta cuando puedas 🔄
6. **Dashboard de KPIs** - Estadísticas de tu trabajo 📊

---

## 🔧 Flujos de Trabajo

### 1. REGISTRAR MANTENIMIENTO PREVENTIVO

**Escenario:** Es viernes, debes hacer mantenimiento preventivo a la Caldera 500 HP en planta sin red.

#### Pasos:
1. Abre la app (funciona sin internet ✓)
2. Selecciona: Cliente → Equipo → Válvula/Componente
3. Toca **"Registrar Nueva Mantención"**
4. Completa:
   - **Tipo:** Selecciona **"Preventivo"** (🟢)
   - **Descripción:** "Mantenimiento preventivo rutinario de válvula PSV-001"
   - **Problemas encontrados:** "Leve suciedad en el filtro"
   - **Solución aplicada:** "Limpieza completa de filtro y lines"
5. **Pruebas Hidráulicas:** Ingresa presiones:
   - Presión entrada: 250 bar
   - Presión salida: 150 bar
   - Sistema registra automáticamente
6. **Fotos:** Toma antes/durante/después (se guardan localmente)
7. **Próxima mantención:** Sistema sugiere "en 6 meses" (puedes cambiar)
8. **Guardar** ✅

**Resultado:** Todo guardado localmente. Cuando vuelvas a oficina y haya internet → sincroniza automáticamente.

---

### 2. CAMBIO DE VÁLVULA/COMPONENTE CRÍTICO

**Escenario:** La válvula reductora PSV-001 falla. Necesitas cambiarla AHORA.

#### Pasos:
1. Abre el equipo en la app
2. Selecciona la válvula que falla
3. En el historial, toca el botón **"Cambiar Componente"**
4. Se abre formulario especial:
   ```
   🔴 COMPONENTE ACTUAL (A RETIRAR)
   ├─ Serie: SN-2024-001 (capturada)
   ├─ Modelo: ASCO 300-05
   └─ La app guarda esta información
   
   🟢 COMPONENTE NUEVO (A INSTALAR)
   ├─ Serial nuevo: [escribes SN-2026-0145]
   ├─ Modelo nuevo: ASCO 300-05
   └─ La app captura automáticamente
   ```
5. **Razón del cambio:** "No mantiene presión, diafragma desgastado"
6. **Prueba funcional:** 
   - ✅ PASA (si funciona bien)
   - ❌ FALLA (si hay problema)
   - ⚠️ PARCIAL (funciona pero limitado)
7. **Fotos:** Antes, durante, después del cambio
8. **Guardar** ✅

**Resultado:** La app genera automáticamente:
- Registro de qué componente salió ✗
- Qué componente entró ✓
- Quién hizo el cambio y cuándo
- Resultado de prueba
- Todo documentado para auditoría

---

### 3. GENERAR REPORTE PARA CLIENTE

**Escenario:** El cliente pide documentación de las dos últimas mantenciones.

#### Pasos:
1. Abre el equipo
2. Ve el **Historial** (timeline visual con todos los trabajos)
3. Selecciona mantenimiento que necesitas reportar
4. Toca **"Generar Reporte PDF"**
5. Se crea automáticamente con:
   - Fecha, hora exacta
   - Qué se cambió
   - Qué se encontró
   - Qué se solucionó
   - Fotos anexadas
   - Firma digital
   - Próxima mantención programada

**Resultado:** Documento profesional listo para entregar. No perder tiempo escribiendo reportes.

---

### 4. VER HISTORIAL COMPLETO DE COMPONENTE

**Escenario:** La Bomba Inyección sigue fallando. Necesitas saber: ¿Cada cuánto se cambia? ¿Por qué?

#### Pasos:
1. Abre Equipo → Componente "Bomba Inyección"
2. Toca **"Ver Historial"**
3. Ves timeline visual:
   ```
   📸 2026-03-10 | Cambio de Bomba
      Serial viejo: SNB-2023-005 → Serial nuevo: SNB-2026-0102
      Razón: Presión baja, funcionamiento intermitente
      Resultado: ✅ PASA

   📸 2026-02-05 | Cambio de Bomba  
      Serial viejo: SNB-2022-089 → Serial nuevo: SNB-2023-005
      Razón: Cavitación en línea de succión
      Resultado: ✅ PASA

   📸 2025-11-20 | Mantenimiento Preventivo
      Limpieza de filtro, prueba de funcionamiento
      Resultado: ✅ PASA
   ```

**Insight:** "Bomba se cambia cada 2 meses. Problema en línea de succión. Recomendar revisión de succión/filtro entrada."

---

### 5. DASHBOARD DE EQUIPO

**Escenario:** Tu jefe quiere saber: "¿Cómo va el mantenimiento de la Caldera?"

#### Pasos:
1. Abre Equipo → Toca **"Dashboard"**
2. Ves automáticamente:
   ```
   📊 15 mantenciones totales
   📅 3 en últimos 30 días
   📦 8 componentes reemplazados
   ✅ 87% efectividad preventiva
   ```
3. **Gráfico de efectividad:**
   - ✅ 12 Preventivos (80%) - VERDE
   - 🔧 3 Correctivos (20%) - NARANJA
   - 🚨 0 Urgentes - VERDE

4. **KPI Insight:** "Excelente mantenimiento preventivo. Mantenerlo."

5. **Próximas mantenciones:**
   - Caldera en 5 días
   - Compresor en 12 días
   - Bomba en 18 días

---

## 🔴 Flujos de EMERGENCIA

### Equipo Falla sin Previo Aviso

1. En la app, **Tipo: "Urgente"** (🔴)
2. Registra problema rápidamente
3. Qué intentaste
4. Qué solucionó
5. **Sincroniza cuando puedas** - la app lo marca como crítico

---

## 💡 CONSEJOS PRÁCTICOS

### ✅ Haz esto:
- Registra **INMEDIATAMENTE** después del trabajo (mientras está fresco)
- Toma fotos siempre (antes/durante/después)
- Completa el serial de componentes reemplzados
- Escribe la razón del cambio claramente
- Próxima mantención: sé realista

### ❌ NO hagas esto:
- Esperes a fin de mes para registrar
- Olvides tomar fotos
- Llenes "No sé" en campos importantes
- Copies/pegues descripciones
- Olvides sincronizar

---

## 🌐 OFFLINE vs ONLINE

### 🔴 Modo OFFLINE (Planta sin red)
- ✅ Registra mantenciones
- ✅ Toma fotos (guardan localmente)
- ✅ Accede a historial
- ✅ Ves cambios anteriores
- 🔴 No sincroniza en tiempo real

### 🟢 Modo ONLINE (De vuelta en oficina)
- ✅ La app detecta internet
- ✅ Sincroniza automáticamente
- ✅ Sube fotos en background
- ✅ Todo actualizado en servidor
- ⚠️ Mientras sincroniza, no desconectes

**Indicador en pantalla:**
- 🟢 Sincronizado ← Todo actualizado
- 🟡 Sincronizando... ← En proceso (no cerrar app)
- 🔴 Offline ← Datos guardados localmente
- ⚠️ Error de sync ← Reintentar cuando tengas red

---

## 📄 TIPOS DE REPORTES QUE PUEDES GENERAR

### 1. Reporte Individual de Mantención
Documento completo de UN trabajo realizado:
- Qué se hizo
- Problemas encontrados  
- Soluciones aplicadas
- Componentes cambiados
- Fotos
- Firma técnico
- Próxima mantención

### 2. Resumen de Equipo (Últimos 3 meses)
Para gerencia/cliente:
- Cuántas mantenciones
- Tipos (preventivo/correctivo/urgente)
- Componentes usados
- Promedio de tiempo por mantenimiento
- Efectividad

### 3. Historial de Componente
Para diagnóstico:
- Cada cambio de ese componente
- Por qué se cambió
- Serial anterior vs nuevo
- Resultado de prueba
- Fotos

---

## 🔒 SEGURIDAD Y AUDITORÍA

Cada registro tiene:
- ✅ Fecha/hora exacta
- ✅ Técnico responsable
- ✅ Descripción detallada
- ✅ Fotos documentación
- ✅ Serial de componentes
- ✅ Historico completo

**Para auditoría:** Todo quedasperfectafectamente documentado y rastreable.

---

## ⚡ ATAJOS ÚTILES

| Acción | Botón |
|--------|-------|
| Nueva mantención | + Rojo en Header |
| Cambiar componente | 📦 Botón en header |
| Ver historial | 📚 Timeline |
| Generar reporte | 📄 Botón flotante |
| Dashboard | 📊 Estadísticas |
| Sincronizar manual | 🔄 Si offline |

---

## ❓ PREGUNTAS FRECUENTES

**P: ¿Qué pasa si se me cierra la app sin guardar?**  
R: No te preocupes. Se guarda automáticamente mientras escribes.

**P: ¿Puedo cambiar datos después?**  
R: Sí, pero quedará registrado "Modificado por X el [fecha]"

**P: ¿Las fotos se comprimen?**  
R: Sí, automáticamente para no usar mucho espacio.

**P: ¿Puedo generar reporte sin internet?**  
R: Sí, se genera en PDF pero no se sincroniza hasta tener red.

**P: ¿Qué pasa con cambios que hice offline?**  
R: Se situan automáticamente en background cuando conectes.

---

## 🚀 EMPEZAR AHORA

1. Abre la app
2. Selecciona tu cliente
3. Selecciona un equipo
4. Toca **"Registrar Nueva Mantención"**
5. Completa datos
6. **Guarda** ✅

¡Eso es! Ahora tienes:
- ✅ Registro digital
- ✅ Histórico accesible
- ✅ Reportes listos
- ✅ Sincronización automática
- ✅ Todo documentado

---

## 📞 SOPORTE

Para problemas:
1. Verifica que tengas última versión
2. Limpia caché si la app va lenta
3. Sincroniza manualmente
4. Reinicia la app

**Es una aplicación para hacerle la vida MÁS FÁCIL, not más difícil.**

Cualquier cosa que te complique → **reportemos mejora.**

¡Buena suerte con tus mantenciones! 🔧💪

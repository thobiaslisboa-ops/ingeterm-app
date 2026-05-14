# 🔐 Configuración de Reglas de Firestore

## ❌ Problema Actual

La app lanza error: **"Missing or insufficient permissions"** al intentar leer datos de Firestore.

Esto ocurre porque las reglas de seguridad están bloqueando el acceso sin autenticación.

---

## ✅ Solución para Desarrollo

### Paso 1: Abre la Consola Firebase
1. Ve a: https://console.firebase.google.com/
2. Selecciona tu proyecto **`mantencion-valvulas`**
3. En el menú lateral, haz clic en **"Firestore Database"**
4. Selecciona la pestaña **"Rules"**

### Paso 2: Copia EXACTAMENTE esto (SIN los backticks al inicio/final)

**COPIA ESTO Y PÉGALO EN FIREBASE (sin backticks):**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

⚠️ **IMPORTANTE:** Los caracteres ` (backtick) que ves arriba son SOLO de markdown. 
**NO** los copies. Solo copia el texto que está entre ellos:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Paso 3: Publica las reglas
1. Haz clic en el botón **"Publish"**
2. Confirma en el diálogo emergente
3. Espera a que se publique (debería tardar unos segundos)

---

## ✅ Solución para Producción (con Autenticación)

Una vez que implementes autenticación en la app, usa estas reglas más seguras:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Requiere autenticación para todas las operaciones
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📊 Estructura de Datos Permitida

Con estas reglas, la app puede operar sobre:

```
clients/
  ├── {clientId}/
  │   ├── name
  │   ├── contactPerson
  │   ├── phone
  │   ├── email
  │   └── equipments/
  │       ├── {equipmentId}/
  │       │   ├── name
  │       │   ├── type
  │       │   ├── tag
  │       │   └── valves/
  │       │       ├── {valveId}/
  │       │       │   ├── name
  │       │       │   ├── tag
  │       │       │   ├── status
  │       │       │   └── maintenance/
  │       │       │       └── {recordId}
  │       └── components/
  │           └── {componentId}
```

---

## 🚨 Notas de Seguridad

⚠️ **Las reglas actuales** (`allow read, write: if true`) son **INSEGURAS** para producción.

✅ **Úsalas SOLO para:**
- Desarrollo local
- Testing y prototipado
- Development en equipo cerrado

❌ **NUNCA las uses en producción** sin autenticación y validación de datos.

---

## 📞 ¿Necesitas Help?

Si después de cambiar las reglas seguís teniendo problemas:

1. **Limpia la caché de la app:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Reinicia la app completamente**

3. **Verifica en la consola Firebase** que las reglas están publicadas (debajo del editor debe decir "Published")

---

**Después de cambiar las reglas, vuelve a correr la app:**
```bash
flutter run -d chrome
```

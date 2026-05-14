# 📚 Guía: Conexión a Firebase desde tu Computador

## 🔐 Información de tu Proyecto

Tu proyecto Flutter está configurado con **Firebase** y los datos se almacenan en la nube.

**Nombre del proyecto:** `mantencion-valvulas`
**Plataformas configuradas:** Web, Android, iOS, Windows, macOS

---

## ✅ Opción 1: Acceso desde la Consola Firebase (Web)

Esta es la forma más fácil para ver y administrar tus datos:

### Pasos:
1. **Abre tu navegador** y ve a: https://console.firebase.google.com/
2. **Inicia sesión** con tu cuenta Google (la misma que usaste para crear el proyecto)
3. **Selecciona tu proyecto:** `mantencion-valvulas`
4. **En el menú lateral**, haz clic en **"Firestore Database"** (base de datos)
5. **Verás tus colecciones:**
   - `clients` (Clientes)
   - Dentro de cada cliente: `equipments` (Equipos)
   - Dentro de cada equipo: `components` (Componentes) y `valves` (Válvulas)
6. **Puedes:**
   - Ver todos tus datos en tiempo real
   - Agregar/editar/eliminar documentos
   - Hacer consultas
   - Ver estadísticas de uso

---

## ✅ Opción 2: Conectarse desde Aplicaciones Externas

Si quieres conectarte desde **Python, Node.js, Java o C#** para hacer operaciones con tus datos:

### A. Con Firebase Admin SDK (Recomendado para aplicaciones de escritorio)

#### Para Python:
```bash
pip install firebase-admin
```

**Ejemplo de código Python:**
```python
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Descargar archivo de credenciales desde Firebase Console
# Ir a: Project Settings > Service Accounts > Generate New Private Key
cred = credentials.Certificate('ruta/a/tu/archivo-clave.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

# Leer clientes
clientes = db.collection('clients').stream()
for doc in clientes:
    print(f'{doc.id} => {doc.to_dict()}')

# Agregar un cliente
db.collection('clients').add({
    'name': 'Mi Empresa',
    'contactPerson': 'Juan Pérez',
    'phone': '123456789',
    'email': 'contacto@empresa.com'
})
```

#### Para Node.js:
```bash
npm install firebase-admin
```

#### Para Java/Android:
```gradle
dependencies {
    implementation 'com.google.firebase:firebase-admin:9.2.0'
}
```

---

## 📋 Pasos para Obtener las Credenciales (Service Account)

Si necesitas conectarte desde una aplicación externa:

1. **Abre Firebase Console:** https://console.firebase.google.com/project/mantencion-valvulas/settings/serviceaccounts/adminsdk
2. **Selecciona el lenguaje** que necesitas (Python, Node.js, Java, etc.)
3. **Haz clic en "Generate New Private Key"**
4. Se descargará un archivo JSON con tus credenciales (⚠️ **guárdalo en lugar seguro**)
5. Usa ese archivo en tu aplicación para conectarte

⚠️ **IMPORTANTE:** No compartas ese archivo JSON públicamente ni lo subas a GitHub

---

## ✅ Opción 3: Conectarse desde Herramientas de Escritorio

### Firebase CLI (Línea de comandos)

Puedes instalar Firebase CLI para hacer operaciones desde tu terminal:

```bash
# Instalar (requiere Node.js)
npm install -g firebase-tools

# Iniciar sesión
firebase login

# Ver datos de tu proyecto
firebase firestore:get /clients

# Exportar datos
firebase firestore:export ./backup

# Restaurar datos
firebase firestore:import ./backup
```

---

## 📊 Estructura de tu Base de Datos

```
Firestore Database (mantencion-valvulas)
│
├── clients (Colección)
│   ├── [client-id] (Documento)
│   │   ├── name: String
│   │   ├── contactPerson: String
│   │   ├── phone: String
│   │   ├── email: String
│   │   └── equipments (Subcolección)
│   │       ├── [equipment-id] (Documento)
│   │       │   ├── name: String
│   │       │   ├── type: String (caldera, autoclave, vap_consumer)
│   │       │   ├── tag: String
│   │       │   ├── manufacturingYear: Number
│   │       │   ├── serialNumber: String
│   │       │   ├── maxWorkingPressure: String
│   │       │   ├── location: String
│   │       │   ├── components (Subcolección)
│   │       │   │   └── [component-id]...
│   │       │   └── valves (Subcolección)
│   │       │       └── [valve-id]...
│   │       └── ...
│   └── ...
│
└── ... (otras colecciones)
```

---

## 🔒 Seguridad

### Reglas de Firestore

Actualmente tus datos están protegidos con reglas de seguridad. Para verificarlas:

1. Abre Firebase Console
2. Ve a **"Firestore Database"** > **"Rules"**

**Regla típica para desarrollo:**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## ❓ Preguntas Frecuentes

### ¿Puedo hacer copias de seguridad?
✅ Sí. Usa el comando:
```bash
firebase firestore:export ./backup
```

### ¿Cómo borro datos?
✅ Desde la consola Firebase o desde código (admin SDK)

### ¿Cuál es el costo?
✅ Firebase tiene un plan gratis con límites. Consulta: https://firebase.google.com/pricing

### ¿Dónde veo el consumo de mi base de datos?
✅ En la consola Firebase, opción "Usage"

---

## 📞 Soporte

- **Documentación Firebase:** https://firebase.google.com/docs
- **Tu proyecto:** https://console.firebase.google.com/project/mantencion-valvulas/

# Setup Local de Plugins Nativos

## Android Plugin

### 0. Requisitos previos

- Android Studio (última versión recomendada)
- Android SDK API 34 instalado
- Gradle 8.0+ (Android Studio lo instala automáticamente)
- Godot 4.3+ o Redot 4.x instalado en tu máquina

### 1. Compilar el plugin

Desde este directorio (`platform_plugins/`):

```bash
# Descarga/actualiza dependencias de Gradle
./gradlew --version  # debe ser 8.0+

# Limpiar builds previos
./gradlew clean

# Compilar el módulo Android
./gradlew :android:assembleRelease
```

**Salida esperada:**
```
BUILD SUCCESSFUL in 15s
```

El AAR compilado queda en:
```
android/build/outputs/aar/android-release.aar
```

### 2. Crear la estructura en tu proyecto Godot

Desde la raíz de tu proyecto Godot:

```bash
mkdir -p addons/opentable_nearby/bin
```

### 3. Copiar el AAR

```bash
cp platform_plugins/android/build/outputs/aar/android-release.aar \
   [TU_PROYECTO_GODOT]/addons/opentable_nearby/bin/OpenTableNearby.aar
```

### 4. Agregar el archivo `.gdap` a tu proyecto Godot

Copia el template:

```bash
cp platform_plugins/android/OpenTableNearby.gdap.template \
   [TU_PROYECTO_GODOT]/OpenTableNearby.gdap
```

**Asegurate de que la ruta en `OpenTableNearby.gdap` coincida con donde copiaste el AAR.**

### 5. Habilitar en Godot

Abre tu proyecto Godot:
1. Ve a **Proyecto → Configuración del Proyecto → Plugins**
2. Busca "OpenTableNearby"
3. Cambia el estado a **Enabled**
4. Recarga/reinicia Godot

### 6. Verificar desde GDScript

En un script de Godot:

```gdscript
var nearby = Engine.get_singleton("OpenTableNearby")
if nearby:
    print("✅ Plugin OpenTableNearby cargado correctamente")
    nearby.peer_discovered.connect(_on_peer_discovered)
    nearby.data_received.connect(_on_data_received)
else:
    print("❌ Plugin no encontrado")

func _on_peer_discovered(endpoint_id: String, endpoint_name: String):
    print("Descubierto: %s (%s)" % [endpoint_name, endpoint_id])

func _on_data_received(endpoint_id: String, data: PackedByteArray):
    print("Datos recibidos de %s: %d bytes" % [endpoint_id, data.size()])
```

### Troubleshooting

**Error: "Gradle not found"**
- Asegúrate de estar en `platform_plugins/`
- En macOS/Linux, da permisos de ejecución: `chmod +x gradlew`

**Error: "API 34 not found"**
- Abre Android Studio
- Ve a SDK Manager (Tools → SDK Manager)
- Instala "Android API 34"

**Error: "Plugin not detected by Godot"**
- Verifica que `OpenTableNearby.gdap` esté en la raíz de tu proyecto Godot
- Verifica que la ruta del AAR en el `.gdap` sea correcta
- Recarga el proyecto completo (File → Close → Reopen)

---

## iOS Plugin (próximas actualizaciones)

Por ahora no hay estructura Gradle, pero el proceso será similar:
- `ios/` tendrá un proyecto Xcode
- El output será un `.xcframework`
- Godot lo detectará vía un `.gdip` similar al `.gdap`

Ver `ios/README.md` cuando esté disponible.

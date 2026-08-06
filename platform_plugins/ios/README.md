# Guía de Integración para iOS (Redot / Godot GDExtension & MultipeerConnectivity)

Esta guía documenta paso a paso el proceso de compilación, empaquetado, configuración de GDExtension y firmado de la aplicación para iOS en Redot/Godot.

---

## Paso 1: Compilar el Crate Rust (`open_table_godot`) como `cdylib` para iOS

Para compilar la librería nativa para dispositivos iOS reales (`aarch64-apple-ios`):

```bash
# Agregar el target de Rust para iOS
rustup target add aarch64-apple-ios

# Compilar en modo release
cargo build --target aarch64-apple-ios --release -p open_table_godot
```

Si vas a probar en el **Simulador de iOS** (Apple Silicon M1/M2/M3/M4):

```bash
rustup target add aarch64-apple-ios-sim
cargo build --target aarch64-apple-ios-sim --release -p open_table_godot
```

El artefacto generado estará disponible en:
- Dispositivo real: `target/aarch64-apple-ios/release/libopen_table_godot.dylib`
- Simulador: `target/aarch64-apple-ios-sim/release/libopen_table_godot.dylib`

---

## Paso 2: Copiar el `.dylib` al Proyecto Xcode Generado por Redot

Una vez exportado el proyecto desde Redot Engine o mediante la CLI:

1. Crear un directorio para binarios iOS en la estructura del proyecto Xcode (p. ej., `Frameworks/` o `ios/bin/`).
2. Copiar el archivo `libopen_table_godot.dylib` compilado en el Paso 1 a esa carpeta.
3. En Xcode, abrir el proyecto `.xcodeproj` generado, ir a la pestaña **General** -> **Frameworks, Libraries, and Embedded Content**, y asegurarse de que `libopen_table_godot.dylib` figure como **Embed & Sign**.

---

## Paso 3: Configurar el `.gdextension` con la Ruta Correcta para iOS

En el archivo `godot_project/opentable.gdextension`, declarar la ruta del binario para las plataformas iOS en depuración y producción:

```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.1
reloadable = true

[libraries]
linux.debug.x86_64 = "res://../target/debug/libopen_table_godot.so"
linux.release.x86_64 = "res://../target/release/libopen_table_godot.so"
ios.debug.aarch64 = "res://bin/ios/libopen_table_godot.dylib"
ios.release.aarch64 = "res://bin/ios/libopen_table_godot.dylib"
```

---

## Paso 4: Verificar que el Bridge Funciona en el Simulador de iOS

1. Compilar el crate especificando el target del simulador:
   `cargo build --target aarch64-apple-ios-sim --release -p open_table_godot`
2. Abrir el proyecto exportado en Xcode y seleccionar un simulador (p. ej., `iPhone 15 Pro`).
3. Ejecutar el proyecto (`Cmd + R`).
4. Verificar en la consola de Xcode que el singleton `OpenTableBridge` se inicializa correctamente sin errores de vinculación dinámica (`dyld: Symbol not found`).

---

## Paso 5: Firmar la App con los Entitlements Necesarios para MultipeerConnectivity

MultipeerConnectivity requiere que la aplicación iOS declare permisos de red local, Bluetooth y servicios Bonjour en `Info.plist`, además de activar el entitlement en el archivo `.entitlements`.

### 5.1 Configuración de `Info.plist`
Asegurarse de incluir las siguientes claves en el `Info.plist` del proyecto iOS:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>OpenTable SDK utiliza la red local para conectar salas P2P sin necesidad de servidor central.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>OpenTable SDK utiliza Bluetooth para descubrir dispositivos cercanos y crear salas de juego P2P.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_opentable._tcp</string>
        <string>_opentable._udp</string>
    </array>
</dict>
</plist>
```

### 5.2 Archivo de Entitlements (`OpenTableMultipeer.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.multipeer-connectivity</key>
    <true/>
</dict>
</plist>
```

### 5.3 Configuración en Xcode
1. En Xcode, seleccionar el Target principal de la app.
2. Ir a **Signing & Capabilities**.
3. Seleccionar tu **Development Team** y un **Provisioning Profile** válido.
4. Agregar el archivo `OpenTableMultipeer.entitlements` en **Code Signing Entitlements**.

---

## Comando Exacto de Exportación de Redot para iOS

Para exportar el proyecto a un archivo `.xcodeproj` de Xcode desde la línea de comandos de Redot en modo headless:

```bash
redot --headless --export-release "iOS" build/ios/OpenTable.xcodeproj
```

*(Nota: Si usas el binario de Godot directamente, reemplaza `redot` por `godot`).*

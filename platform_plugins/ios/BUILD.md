# Compilación e Integración del Plugin iOS `OpenTableMultipeer`

Este documento explica cómo compilar **`OpenTableMultipeer`** como un `XCFramework` (`OpenTableMultipeer.xcframework`) sobre `MultipeerConnectivity` (iOS 15+) e integrarlo en Godot 4 / Redot.

---

## 1. Requisitos Previos

- **macOS** con **Xcode 16+** y Command Line Tools instalados (`xcode-select --install`).
- Target mínimo: **iOS 15.0** (`arm64-apple-ios15.0` y `arm64-apple-ios15.0-simulator`).
- Framework del sistema: **`MultipeerConnectivity`** (incluido en el SDK de iOS, sin dependencias externas).

Archivos incluidos en `platform_plugins/ios/`:
- `Package.swift` — Definición de Swift Package Manager para el target `OpenTableMultipeer`.
- `OpenTableMultipeerPlugin.swift` — Puente C-ABI / Godot iOS Plugin.
- `OpenTableMultipeerNetwork.swift` — Sesión `MCSession`, `MCNearbyServiceAdvertiser` y `MCNearbyServiceBrowser`.
- `OpenTableMultipeer.swift` — Fachada de alto nivel del adaptador P2P.
- `OpenTableMultipeer.gdip` — Descriptor de plugin iOS para Godot/Redot.

---

## 2. Generación Local de `OpenTableMultipeer.xcframework`

Ejecuta desde la raíz del repositorio en macOS:

```bash
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

mkdir -p build/ios-device build/ios-sim

# 1. Compilar para dispositivo iOS (arm64)
swiftc -parse-as-library \
  -module-name OpenTableMultipeer \
  -whole-module-optimization \
  -target arm64-apple-ios15.0 \
  -sdk "$IPHONEOS_SDK" \
  -emit-object \
  platform_plugins/ios/OpenTableMultipeerNetwork.swift \
  platform_plugins/ios/OpenTableMultipeer.swift \
  platform_plugins/ios/OpenTableMultipeerPlugin.swift \
  -o build/ios-device/OpenTableMultipeer.o
libtool -static -o build/ios-device/libOpenTableMultipeer.a build/ios-device/OpenTableMultipeer.o

# 2. Compilar para simulador iOS (arm64)
swiftc -parse-as-library \
  -module-name OpenTableMultipeer \
  -whole-module-optimization \
  -target arm64-apple-ios15.0-simulator \
  -sdk "$IPHONESIM_SDK" \
  -emit-object \
  platform_plugins/ios/OpenTableMultipeerNetwork.swift \
  platform_plugins/ios/OpenTableMultipeer.swift \
  platform_plugins/ios/OpenTableMultipeerPlugin.swift \
  -o build/ios-sim/OpenTableMultipeer.o
libtool -static -o build/ios-sim/libOpenTableMultipeer.a build/ios-sim/OpenTableMultipeer.o

# 3. Empaquetar en XCFramework
rm -rf OpenTableMultipeer.xcframework
xcodebuild -create-xcframework \
  -library build/ios-device/libOpenTableMultipeer.a \
  -library build/ios-sim/libOpenTableMultipeer.a \
  -output OpenTableMultipeer.xcframework
```

También puedes validar el paquete con SwiftPM:
```bash
cd platform_plugins/ios
swift build -c release --sdk "$IPHONEOS_SDK" --triple arm64-apple-ios15.0
```

---

## 3. Cómo Copiar el XCFramework al Proyecto Godot

1. Crear el directorio de plugins iOS en `godot_project/`:
   ```bash
   mkdir -p godot_project/ios/plugins
   ```

2. Copiar `OpenTableMultipeer.xcframework` y `OpenTableMultipeer.gdip`:
   ```bash
   cp -R OpenTableMultipeer.xcframework godot_project/ios/plugins/
   cp platform_plugins/ios/OpenTableMultipeer.gdip godot_project/ios/plugins/
   ```

3. En el editor de Godot/Redot (**Project → Export → iOS → Plugins**), activar el plugin **`OpenTableMultipeer`** y asegurarse de incluir la clave `NSLocalNetworkUsageDescription` y `NSBonjourServices` (`_opentable._tcp`) en `Info.plist`.

---

## 4. Integración Continua (`.github/workflows/ci.yml`)

El job `build-ios-plugin` se ejecuta en `macos-latest`:
- Verifica los crates de Rust para `aarch64-apple-ios`.
- Compila los objetos Swift para dispositivo y simulador iOS 15.0.
- Empaqueta `OpenTableMultipeer.xcframework` con `xcodebuild -create-xcframework`.
- Publica `OpenTableMultipeer.xcframework` como artefacto del workflow (`actions/upload-artifact@v4`).

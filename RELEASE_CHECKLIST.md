# Checklist de Lanzamiento Comercial y Open-Source (`RELEASE_CHECKLIST.md`)

Esta guía define todos los requisitos legales, técnicos y de empaquetado para publicar **OpenTable SDK & Suite (13 Juegos)** tanto en repositorios de código abierto (GitHub, Crates.io) como en tiendas digitales comerciales (Steam, Itch.io, Google Play y Apple App Store) bajo la licencia **`GPL-3.0-or-later`**.

---

## 1. Cumplimiento Legal y Licencia (`GPL-3.0-or-later`)

### 1.1 Verificación de Archivos Legales en la Raíz y Distribución
Antes de generar cualquier artefacto o etiqueta de versión (`git tag`), confirma que los siguientes archivos estén presentes y actualizados en la raíz del repositorio y dentro de los paquetes `.tar.gz` / `.zip` de distribución:

- [ ] **`LICENSE`**: Texto íntegro de la **GNU General Public License v3.0 (o posterior)** junto con la **Excepción de Enlace Adicional (Sección 7 de la GPLv3)** que autoriza explícitamente enlazar y distribuir binarios combinados con:
  1. **Godot Engine / Redot Engine** (`MIT`).
  2. **Google Play Services Nearby Connections** (`com.google.android.gms:play-services-nearby`) y Android SDK/NDK.
  3. **Apple `MultipeerConnectivity`** e iOS/macOS System Frameworks.
  4. **Valve Steamworks SDK** (`steamworks-rs` / `libsteam_api`).
- [ ] **`THIRD_PARTY_LICENSES.md`**: Inventario actualizado de dependencias de Rust, Godot y fuentes tipográficas/iconografía con sus respectivos avisos de copyright.
- [ ] **`PRIVACY_POLICY.md` y `TERMS_OF_SERVICE.md`**: Políticas de privacidad (sin telemetría invasiva, cumplimiento GDPR/CCPA y soporte de modo invitado local/P2P).
- [ ] **Pantalla de Créditos (`godot_project/scenes/credits_screen.gd`)**: Verifica que la sección `LICENCIA DEL PROYECTO` en la UI del juego muestre `GPL-3.0-or-later (GNU General Public License v3.0 or later)` con la nota de excepción de enlace para Godot/Redot y SDKs de plataforma.

---

### 1.2 Encabezados SPDX (`SPDX-License-Identifier`)
Todos los archivos de código fuente propios del proyecto deben incluir el encabezado estándar SPDX en las primeras líneas para garantizar trazabilidad con herramientas de auditoría como `reuse` o `cargo-deny`.

#### En archivos Rust (`.rs`), Kotlin (`.kt`) y Swift (`.swift`):
```rust
// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later
```

#### En scripts de Godot/Redot (`.gd`), Shell (`.sh`) y archivos de configuración (`.toml`, `.yml`):
```gdscript
# SPDX-FileCopyrightText: 2026 OpenTable Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
```

#### Auditoría rápida de encabezados y metadatos `Cargo.toml`:
Ejecuta desde la raíz del proyecto para confirmar que los 22 `Cargo.toml` declaran `license = "GPL-3.0-or-later"`:
```bash
grep -rn '^license = ' Cargo.toml */Cargo.toml
```

Para auditar las licencias de todas las dependencias del grafo de Cargo mediante `cargo-deny` (`deny.toml`):
```bash
cargo deny check licenses
```
> **Nota**: `deny.toml` permite `GPL-3.0-or-later` para los crates del workspace y licencias permisivas compatibles (`MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `Unicode-3.0`, `Zlib`, `MPL-2.0`, `CC0-1.0`) para las dependencias externas.

---

### 1.3 Requisitos para Distribución Comercial (Steam, Itch.io, Google Play, App Store)
La licencia **GPL-3.0-or-later** permite vender copias binarias comerciales del juego y del SDK en tiendas digitales siempre que se cumplan estas tres condiciones:

1. **Oferta de Código Fuente (*Source Code Availability*)**:
   - Incluye en la pantalla de Créditos, en el archivo `README.md` empaquetado junto al ejecutable y en la descripción de la tienda el enlace directo al repositorio público: `https://github.com/joduranvillan/games_tables_sdk` y al tag exacto de la versión compilada (ej. `v1.0.0`).
2. **Prohibición de DRM Restrictivo sobre el Binario GPL (Cláusula Anti-Tivoización de GPLv3)**:
   - En **Steam**: No actives el wrapper propietario *Steam Stub DRM* sobre el ejecutable si impide al usuario ejecutar su propia versión compilada localmente; utiliza la integración opcional de `steamworks-rs` cubierta por la Excepción de Enlace de `LICENSE`.
   - En **App Store / Google Play**: El firmado estándar de paquetes (`.aab` / `.apk` / `.ipa`) por parte del desarrollador, respaldado por la Excepción de Enlace de `LICENSE` para SDKs de plataforma, permite publicar en mercados móviles manteniendo el código fuente completo disponible en el repositorio oficial.
3. **Preservación de Avisos Legales**:
   - Los archivos `LICENSE` y `THIRD_PARTY_LICENSES.md` deben copiarse en la raíz del paquete distribuido (`dist/opentable-linux-x86_64/` y `dist/opentable-windows-x86_64/`).

---

## 2. Certificación Técnica Pre-Release (Motor y 13 Juegos)

Antes de empaquetar, todos los controles de calidad automatizados deben aprobar sin errores ni advertencias:

- [ ] **1. Suite de Pruebas Deterministas en Rust (Workspace completo)**:
  ```bash
  cargo test --workspace --exclude open_table_godot
  ```
  Verifica:
  - Reglas canónicas (`tests/canonical_rules.rs`) en los 13 juegos (`checkers`, `chess`, `ludo`, `uno`, `mille_bornes`, `monopoly`, `backgammon`, `battleship`, `chinese_checkers`, `crisis`, `go`, `shogi`, `xiangqi`).
  - Determinismo de snapshots, serialización de replays `.otr` (`bincode`), reconexión TCP/WebSocket y cálculo de ELO.

- [ ] **2. Validador Estático Redot 4.x Strict y Smoke Tests de Godot (43 suites)**:
  ```bash
  bash tools/run_godot_tests.sh
  ```
  Verifica:
  - `0` inferencias implícitas `:=` sobre expresiones `Variant` / `Dictionary` / `Array` en GDScript.
  - Paridad 13/13 de scripts de tablero entre `godot_project/<juego>_board.gd` y `godot_project/scenes/<juego>_board.gd`.
  - Validación de las 5 secciones canónicas de `RulesCatalog` (`DEFAULT_MODES`, `RULES`, `TUTORIAL_STEPS`, `RULES_SUMMARY`, `MODE_VARIANTS`) para los 13 juegos.
  - HUD compacto sin solapamiento de etiquetas de jugador y con badge regresivo `MM:SS` (`00:30`) activo en `TurnIndicator`.

- [ ] **3. Verificación de Formato y Linter en Rust**:
  ```bash
  cargo fmt --all -- --check
  cargo clippy --workspace --exclude open_table_godot -- -D warnings
  ```

---

## 3. Empaquetado del Motor Rust (`open_table_godot` y `open_table_relay`)

El puente nativo GDExtension (`open_table_godot`) expone una única clase `#[derive(GodotClass)]` llamada **`OpenTableBridge`** para mantener compatibilidad estricta con `gdext` 0.2.4 en todas las plataformas.

### 3.1 Compilación de Librerías Dinámicas por Plataforma

Asegúrate de exportar `GODOT4_GDEXTENSION_JSON` apuntando al contrato de API local para evitar depender de un binario de Godot durante la compilación de Rust:

```bash
export GODOT4_GDEXTENSION_JSON="$(pwd)/extension_api.json"
```

| Plataforma | Target de Rust (`rustup target add ...`) | Comando de Compilación | Artefacto Generado | Destino en Godot (`godot_project/bin/`) |
|---|---|---|---|---|
| **Linux (x86_64)** | `x86_64-unknown-linux-gnu` | `cargo build --release -p open_table_godot` | `target/release/libopen_table_godot.so` | `godot_project/bin/libopen_table_godot.so` |
| **Windows (x86_64)** | `x86_64-pc-windows-gnu` o `msvc` | `cargo build --release --target x86_64-pc-windows-gnu -p open_table_godot` | `target/x86_64-pc-windows-gnu/release/open_table_godot.dll` | `godot_project/bin/open_table_godot.dll` |
| **macOS (Universal)** | `x86_64-apple-darwin` + `aarch64-apple-darwin` | `cargo build --release --target x86_64-apple-darwin -p open_table_godot && cargo build --release --target aarch64-apple-darwin -p open_table_godot && lipo -create -output libopen_table_godot.dylib target/x86_64-apple-darwin/release/libopen_table_godot.dylib target/aarch64-apple-darwin/release/libopen_table_godot.dylib` | `libopen_table_godot.dylib` | `godot_project/bin/libopen_table_godot.dylib` |
| **Android (ARM64)** | `aarch64-linux-android` | `cargo ndk -t arm64-v8a build --release -p open_table_godot` | `target/aarch64-linux-android/release/libopen_table_godot.so` | `godot_project/bin/android/arm64-v8a/libopen_table_godot.so` |
| **Android (x86_64)** | `x86_64-linux-android` | `cargo ndk -t x86_64 build --release -p open_table_godot` | `target/x86_64-linux-android/release/libopen_table_godot.so` | `godot_project/bin/android/x86_64/libopen_table_godot.so` |
| **iOS (ARM64)** | `aarch64-apple-ios` | `cargo build --release --target aarch64-apple-ios -p open_table_godot` | `target/aarch64-apple-ios/release/libopen_table_godot.dylib` | `godot_project/bin/ios/libopen_table_godot.dylib` |

### 3.2 Empaquetado Automatizado de Escritorio y Servidor Relay (`tools/package_release.sh`)

Para compilar `open_table_godot` y `open_table_relay`, copiar el addon `addons/open_table`, exportar los ejecutables de Godot/Redot y generar los paquetes finales junto con sus sumas SHA-256:

```bash
bash tools/package_release.sh
```

Artefactos generados en `dist/`:
- `dist/opentable-linux-x86_64.tar.gz` (incluye `libopen_table_godot.so`, `open_table_relay`, `addons/open_table`, `assets/` y ejecutable Linux).
- `dist/opentable-windows-x86_64.zip` (incluye `open_table_godot.dll`, `addons/open_table`, `assets/` y ejecutable Windows).
- `dist/SHA256SUMS.txt` (sumas de verificación criptográfica para adjuntar en GitHub Releases).

### 3.3 Publicación de Crates del SDK en Crates.io (`tools/publish_sdk.sh`)

Para publicar las librerías base del SDK en Crates.io respetando el orden topológico de dependencias (`open_table_macros` → `open_table_core` → `open_table_engine` → `open_table_qr` → transportes):

```bash
# 1. Simulación en seco (dry-run)
bash tools/publish_sdk.sh --dry-run

# 2. Incremento de versión y creación de tag git
bash tools/release.sh --patch

# 3. Publicación efectiva en Crates.io
bash tools/publish_sdk.sh
```

---

## 4. Empaquetado de Plugins Nativos de Plataforma para Godot (Android e iOS)

Para habilitar el transporte P2P transparente sin configuración (`OpenTableNearby` en Android vía Wi-Fi Direct / BLE y `OpenTableMultipeer` en iOS vía `MultipeerConnectivity`), compila e integra los plugins nativos antes de exportar desde Godot/Redot.

### 4.1 Plugin Android (`OpenTableNearby-release.aar`)

#### Requisitos:
- **JDK 17** (Temurin / OpenJDK 17)
- **Android SDK** (`compileSdk = 34`, `minSdk = 21`, `targetSdk = 34`) y **NDK r27**

#### Paso a paso de compilación e instalación:
1. **Compilar el paquete `.aar` en modo Release**:
   ```bash
   cd platform_plugins
   ./gradlew :android:assembleRelease --no-daemon
   cd ..
   ```
   Esto genera: `platform_plugins/android/build/outputs/aar/OpenTableNearby-release.aar`.

2. **Ejecutar los tests unitarios del plugin Android**:
   ```bash
   cd platform_plugins
   ./gradlew :android:testDebugUnitTest --no-daemon
   cd ..
   ```

3. **Copiar el `.aar` y el descriptor `.gdap` al proyecto Godot**:
   ```bash
   mkdir -p godot_project/android/plugins
   cp platform_plugins/android/build/outputs/aar/OpenTableNearby-release.aar godot_project/android/plugins/
   cp platform_plugins/android/OpenTableNearbyPlugin.gdap godot_project/android/plugins/
   ```

4. **Verificar permisos y preset de exportación Android (`godot_project/export_presets.cfg`)**:
   - Confirmar que el plugin `OpenTableNearbyPlugin` está habilitado en el preset Android.
   - Confirmar permisos en `AndroidManifest.xml`: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `NEARBY_WIFI_DEVICES`, `ACCESS_FINE_LOCATION`, `INTERNET`.

---

### 4.2 Plugin iOS (`OpenTableMultipeer.xcframework`)

#### Requisitos:
- **macOS** con **Xcode 16+** y Command Line Tools (`xcode-select --install`).
- Target mínimo: **iOS 15.0** (`arm64-apple-ios15.0` y `arm64-apple-ios15.0-simulator`).

#### Paso a paso de compilación e instalación:
1. **Compilar las librerías estáticas para dispositivo físico y simulador y crear el `XCFramework`**:
   ```bash
   IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
   IPHONESIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

   mkdir -p build/ios-device build/ios-sim

   # Dispositivo físico (arm64-apple-ios15.0)
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

   # Simulador (arm64-apple-ios15.0-simulator)
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

   # Empaquetado XCFramework
   rm -rf OpenTableMultipeer.xcframework
   xcodebuild -create-xcframework \
     -library build/ios-device/libOpenTableMultipeer.a \
     -library build/ios-sim/libOpenTableMultipeer.a \
     -output OpenTableMultipeer.xcframework
   ```

2. **Copiar el `XCFramework` y el descriptor `.gdip` al proyecto Godot**:
   ```bash
   mkdir -p godot_project/ios/plugins
   cp -R OpenTableMultipeer.xcframework godot_project/ios/plugins/
   cp platform_plugins/ios/OpenTableMultipeer.gdip godot_project/ios/plugins/
   ```

3. **Configurar `Info.plist` y `OpenTableMultipeer.entitlements`**:
   - Verificar que `Info.plist` incluya `NSLocalNetworkUsageDescription` y `NSBonjourServices` con `_opentable._tcp` y `_opentable._udp` (plantilla disponible en `platform_plugins/ios/Info.plist.template`).

---

## 5. Checklist Final de Publicación en Tiendas y Servidor Relay

- [ ] **GitHub Releases (`.github/workflows/release.yml`)**:
  - Subir tag semántico (`git push origin v1.0.0`) para disparar la compilación matriz en GitHub Actions y adjuntar `opentable-linux-x86_64.tar.gz`, `opentable-windows-x86_64.zip`, `OpenTableNearby-release.aar`, `OpenTableMultipeer.xcframework` y `SHA256SUMS.txt`.
- [ ] **Steamworks (`store/steam/`)**:
  - Verificar capsules y capturas según `store/CHECKLIST_ASSETS.md`.
  - Ejecutar `bash store/steam/upload_steam.sh` con `STEAM_USERNAME` configurado para subir los depots Linux (`depot_build_linux.vdf`), Windows (`depot_build_windows.vdf`) y macOS (`depot_build_macos.vdf`).
- [ ] **Itch.io (`store/itch/`)**:
  - Ejecutar `bash store/itch/update_page.sh` (utiliza `butler push` para los canales `linux-universal`, `windows-universal` y `android`).
- [ ] **Google Play Store (`store/android/fastlane/`)**:
  - Verificar metadatos `en-US` y `es-ES` en `store/android/fastlane/metadata/android/` y publicar el Android App Bundle (`.aab`) firmado con `fastlane supply`.
- [ ] **Servidor Relay Público (`open_table_relay`)**:
  - Desplegar con Docker Compose (`open_table_relay/docker-compose.yml`), verificando certificados TLS en Nginx (`open_table_relay/nginx/nginx.conf`), métricas Prometheus (`/metrics`) y panel Grafana (`open_table_relay/grafana/dashboard.json`).

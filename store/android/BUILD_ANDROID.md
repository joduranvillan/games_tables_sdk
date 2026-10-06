# Guía de Compilación, Firma APK y Publicación en Google Play (`BUILD_ANDROID.md`)

Este documento detalla el flujo completo para compilar la librería nativa `open_table_godot` para Android (`arm64-v8a`), exportar el proyecto Godot/Redot, firmar el APK/AAB y publicarlo en **Google Play Internal Testing** mediante Fastlane.

---

## 1. Generación del Keystore de Firma (Fuera del Repositorio)

Nunca subas archivos `.keystore` o `.jks` al repositorio Git. Genera tu clave de producción localmente:

```bash
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias opentable_release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Para almacenar el keystore en GitHub Actions como secreto en Base64:

```bash
base64 -w 0 release.keystore > release.keystore.b64
```

---

## 2. GitHub Secrets Requeridos

Configura los siguientes secretos en **Settings -> Secrets and variables -> Actions** del repositorio:

| Nombre del Secret | Descripción |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Contenido del archivo `release.keystore` codificado en Base64 (`base64 -w 0`). |
| `ANDROID_KEY_ALIAS` | Alias de la llave dentro del keystore (por ejemplo, `opentable_release`). |
| `ANDROID_KEY_PASSWORD` | Contraseña de la llave y del almacén (`keystore`). |
| `GOOGLE_PLAY_JSON` | Contenido íntegro del JSON de la cuenta de servicio (Service Account) de Google Play Console con permisos de lanzamiento. |

---

## 3. Compilación Cruzada de Rust para Android (`arm64-v8a`)

Con el Android NDK instalado y `cargo-ndk` configurado:

```bash
rustup target add aarch64-linux-android
cargo ndk -t arm64-v8a build --release -p open_table_godot
```

El binario resultante se ubicará en:
`target/aarch64-linux-android/release/libopen_table_godot.so`
(referenciado automáticamente por `godot_project/opentable.gdextension` y `godot_project/addons/open_table/open_table.gdextension`).

---

## 4. Configuración de `export_presets.cfg` en Godot / Redot

En el editor de Godot/Redot (**Proyecto -> Exportar -> Añadir... -> Android**):

1. **Architectures**: Activa `arm64-v8a` (`architectures/arm64-v8a=true`).
2. **Package**:
   - `unique_name`: `org.opentable.sdk`
   - `name`: `OpenTable`
3. **Plugins**: Activa el plugin nativo `OpenTableNearby` (`godot_project/OpenTableNearby.gdap`) compilado mediante:
   ```bash
   cd platform_plugins && ./gradlew :android:assembleRelease
   ```
4. Exporta el APK sin firmar (o firmado en CI):
   ```bash
   redot --headless --path godot_project --export-release "Android" ../dist/opentable-unsigned.apk
   ```

---

## 5. Ejecución de Fastlane (`fastlane beta`)

En entorno local o CI, decodifica el keystore y ejecuta el lane `beta` definido en `store/android/fastlane/Fastfile`:

```bash
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > /tmp/release.keystore
export KEYSTORE_PATH="/tmp/release.keystore"
export ANDROID_KEY_ALIAS="opentable_release"
export ANDROID_KEY_PASSWORD="tu_password"
export GOOGLE_PLAY_JSON="$(cat service-account.json)"

cd store/android
bundle exec fastlane android beta
```

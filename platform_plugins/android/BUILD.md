# Compilación e Integración del Plugin Android `OpenTableNearby`

Este documento detalla cómo compilar `OpenTableNearbyPlugin` como archivo `.aar` (`OpenTableNearby-release.aar`) para Godot 4 / Redot tanto en entorno local (CLI o Android Studio) como en GitHub Actions CI.

---

## 1. Requisitos Previos

- **JDK 17** (Temurin / OpenJDK 17)
- **Android SDK** (`compileSdk = 34`, `minSdk = 21`, `targetSdk = 34`) y **NDK r27**
- **Gradle 8.5+** (o wrapper `./gradlew` incluido en `platform_plugins/`)

Dependencias declaradas en `build.gradle.kts`:
- `com.google.android.gms:play-services-nearby:19.3.0`
- `org.godotengine:godot:4.2.2.stable` (`compileOnly`)

---

## 2. Compilación desde Línea de Comandos (CLI)

Desde la raíz del repositorio:

```bash
cd platform_plugins
./gradlew :android:assembleRelease --no-daemon
```

O directamente dentro de `platform_plugins/android/`:

```bash
cd platform_plugins/android
../gradlew assembleRelease --no-daemon
```

El artefacto compilado se genera en:
- `platform_plugins/android/build/outputs/aar/OpenTableNearby-release.aar`

---

## 3. Compilación desde Android Studio

1. Abrir **Android Studio Ladybug (2024.2+)** y seleccionar **Open** → `platform_plugins/android/` (o `platform_plugins/`).
2. Esperar a que finalice la sincronización de Gradle con JDK 17.
3. En el panel **Build Variants**, seleccionar la variante **release**.
4. Ejecutar **Build → Make Module 'android' (`assembleRelease`)**.

---

## 4. Cómo Copiar el `.aar` al Proyecto Godot

1. Crear la carpeta de plugins Android dentro del proyecto Godot si no existe:
   ```bash
   mkdir -p godot_project/android/plugins
   ```

2. Copiar el `.aar` y el descriptor `.gdap`:
   ```bash
   cp platform_plugins/android/build/outputs/aar/OpenTableNearby-release.aar godot_project/android/plugins/
   cp platform_plugins/android/OpenTableNearbyPlugin.gdap godot_project/android/plugins/
   ```

3. En `godot_project/export_presets.cfg` (o desde **Project → Export → Android → Plugins**), marcar como activo **`OpenTableNearbyPlugin`**.

---

## 5. Integración Continua (`.github/workflows/ci.yml`)

El job `build-android-plugin` se ejecuta automáticamente en cada `push` y `pull_request` sobre `ubuntu-latest`:
- Configura JDK 17 (`actions/setup-java@v6`) y Gradle 8.5 (`gradle/actions/setup-gradle@v6`).
- Ejecuta `./gradlew :android:assembleRelease --no-daemon`.
- Publica `OpenTableNearby-release.aar` como artefacto descargable del workflow (`actions/upload-artifact@v4`).

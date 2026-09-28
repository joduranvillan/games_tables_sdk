# Compilación del Plugin Android OpenTableNearby

## Prerrequisitos
- Android Studio Ladybug (2024.2+)
- NDK r27 o superior
- Gradle 8.x

## Pasos

1. Abrir `platform_plugins/android/` como proyecto en Android Studio.
2. En `build.gradle`, verificar `compileSdk = 34` y `minSdk = 24`.
3. Build → Build Bundle(s)/APK(s) → Build AAR.
4. Copiar el `.aar` resultante a `godot_project/android/plugins/`.
5. En `godot_project/project.godot`, añadir bajo `[android]`:
   ```ini
   plugins="OpenTableNearbyPlugin"
   ```
6. Exportar el proyecto con Redot 4.5.2 para Android (arm64-v8a).

## CI automatizado (pendiente)

- Añadir job `android-plugin` en `.github/workflows/` usando `actions/setup-java@v6` y `gradle build` en el directorio del plugin.

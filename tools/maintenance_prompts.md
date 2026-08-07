# Meta-Prompts de Mantenimiento Recurrente

Este documento contiene un conjunto de 10 meta-prompts reutilizables para tareas de mantenimiento recurrente del SDK Open Table y el proyecto Godot.

---

### 1. Correr todos los tests y reportar fallos
**Prompt:**
> Ejecuta la suite completa de pruebas unitarias y de integración de Rust en todo el workspace, reportando cualquier fallo detalladamente.

**Comando exacto:**
```bash
cargo test --workspace
```

---

### 2. Actualizar dependencias a las últimas versiones compatibles
**Prompt:**
> Actualiza los archivos de lockfile de dependencias en el workspace a las últimas versiones compatibles según SemVer.

**Comando exacto:**
```bash
cargo update
```

---

### 3. Verificar que todos los juegos compilan sin warnings
**Prompt:**
> Verifica que todos los crates de juegos y el bridge de Godot compilen de forma limpia sin ninguna advertencia o error de compilación.

**Comando exacto:**
```bash
RUSTFLAGS="-D warnings" cargo check --workspace --all-targets
```

---

### 4. Regenerar la documentación rustdoc
**Prompt:**
> Genera la documentación completa de Rust (rustdoc) para todos los crates del workspace sin incluir dependencias externas.

**Comando exacto:**
```bash
cargo doc --workspace --no-deps
```

---

### 5. Actualizar el CHANGELOG con los commits recientes
**Prompt:**
> Ejecuta el script de generación de CHANGELOG para categorizar y resumir los commits realizados desde la última versión/tag.

**Comando exacto:**
```bash
./tools/generate_changelog.sh
```

---

### 6. Verificar que los tests de Godot headless pasan
**Prompt:**
> Ejecuta toda la suite de pruebas de integración y humo de Godot en modo headless para confirmar la compatibilidad del bridge y la UI.

**Comando exacto:**
```bash
./tools/run_godot_tests.sh
```

---

### 7. Correr el análisis de cobertura de código
**Prompt:**
> Genera el informe de cobertura de código para todo el workspace utilizando `llvm-cov` e inspecciona los resultados.

**Comando exacto:**
```bash
./tools/coverage.sh
```

---

### 8. Verificar que no hay advisories de seguridad en cargo-deny
**Prompt:**
> Analiza las dependencias del proyecto utilizando `cargo-deny` para detectar vulnerabilidades o avisos de seguridad conocidos.

**Comando exacto:**
```bash
cargo deny check advisories
```

---

### 9. Actualizar los snapshots visuales de tests de UI
**Prompt:**
> Ejecuta el test de regresión visual de Godot con el flag para actualizar los snapshots de referencia de la interfaz gráfica.

**Comando exacto:**
```bash
redot --headless --path godot_project --script res://tests/visual_regression.gd -- --update-snapshots
```

---

### 10. Verificar que la suite de proptest no encontró nuevos fallos
**Prompt:**
> Ejecuta las pruebas basadas en propiedades (proptest) aumentando el número de casos generados aleatoriamente para verificar invarianza.

**Comando exacto:**
```bash
PROPTEST_CASES=1000 cargo test --workspace
```

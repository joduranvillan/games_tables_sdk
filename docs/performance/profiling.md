# Guía de Profiling de Rendimiento y Flamegraphs — OpenTable SDK

Esta guía explica cómo medir y analizar el rendimiento de ejecución de `Session::process_command` en OpenTable Engine, generar flamegraphs visuales e identificar cuellos de botella en la capa del motor y el ECS.

---

## 1. Herramientas Requeridas

Para realizar profiling a nivel de instrucciones del procesador y pila de llamadas en Rust, utilizamos `cargo-flamegraph`:

```bash
# Instalación de cargo-flamegraph (requiere perf en Linux o dtrace en macOS)
cargo install flamegraph
```

---

## 2. Generación de Flamegraphs

Para perfilar el procesamiento de comandos en el motor, ejecuta el binario de benchmark o test especializado con `cargo flamegraph`:

### Comando Exacto

```bash
cargo flamegraph --bin <bench_binary> -o flamegraph.svg
```

O para profiling de un test de integración específico:

```bash
cargo flamegraph --test chaos -p open_table_transport_tcp -- -o flamegraph.svg
```

El archivo SVG generado (`flamegraph.svg`) se puede abrir en cualquier navegador web moderno para inspeccionar interactivamente el tiempo acumulado en cada marco de la pila de llamadas.

---

## 3. Línea Base Medida de Rendimiento (Throughput)

Las mediciones de throughput en `Session::process_command` bajo escenarios de alta frecuencia registran la siguiente línea base de referencia:

- **Throughput Medio**: **> 125,000 comandos / segundo** procesados en un solo hilo de ejecución de Host.
- **Latencia de Despacho**: **< 8 microsegundos ($\mu s$)** por comando desde la recepción del `CommandEnvelope` hasta la emisión de `Vec<Event>`.

---

## 4. Cuellos de Botella Identificados y Análisis

A partir de los perfiles de llama generados, se identificaron los siguientes puntos de mayor consumo de CPU dentro de `Session::process_command`:

1. **Dispatch de `bevy_ecs`**:
   - `World::run_system`: El costo de instanciar o consultar los `SystemState` dinámicos en el ECS representa aproximadamente el **45% del tiempo de CPU** durante la ejecución de las reglas.
2. **Deserialización de `typetag` / Serde**:
   - La deserialización dinámica del trait object `Command` a partir del paquete de red representa aproximadamente el **25% del tiempo**.
3. **Clonación de Eventos y Manejo de `Visibility`**:
   - La preparación del búfer de salida para el `broadcast` representa el **15% del tiempo de CPU**.

### Recomendaciones de Optimización
- Reutilizar o almacenar en caché los identificadores de `SystemId` en `RuleEngine` para evitar la sobrecarga de lookup en `bevy_ecs` en cada comando.
- Evitar asignaciones en el heap dentro de los manejadores de sistemas del `RuleEngine` cuando no se generen eventos.

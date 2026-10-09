# Licencias de Software Open Source de Terceros (Third-Party Open Source Licenses)
**Producto:** OpenTable — 13 Classic Board & Card Games (v3.0.0)  
**Cumplimiento de atribución:** Distribuciones binarias comerciales en Steam, Google Play, Apple App Store, Itch.io y Web (WASM).

---

## 1. Motor Gráfico y Runtime (Godot Engine / Redot Engine)

### Godot Engine & Redot Engine
- **Licencia:** MIT License
- **Copyright:**
  - Copyright (c) 2024-present Redot Engine contributors.
  - Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
  - Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
- **Componentes incluidos:** Runtime 2D/UI, FreeType (FTL/GPLv2 con excepción), MiniUPnP (BSD-3-Clause), MbedTLS (Apache-2.0), zlib (Zlib).

---

## 2. Ecosistema Rust y Puente Nativo (`Cargo.lock`)

| Paquete / Crate | Uso en OpenTable | Licencia |
|-----------------|------------------|----------|
| `open_table_core`, `open_table_engine`, `open_table_godot`, `open_table_relay` | SDK determinista de mesa, IA y servidor Relay | MIT |
| `godot` (`gdext`) | Bindings Rust para GDExtension (Godot 4) | MPL-2.0 |
| `serde`, `serde_json` | Serialización determinista de estados y comandos | MIT OR Apache-2.0 |
| `tokio`, `tokio-tungstenite`, `futures-util` | Runtime asíncrono y transporte WebSocket | MIT |
| `axum`, `tower`, `tower-http`, `hyper` | API HTTP/REST (`/auth/guest`, `/health`, `/leaderboard`) | MIT |
| `rustls`, `tokio-rustls`, `rcgen` | Cifrado TLS/WSS puro en Rust sin OpenSSL | Apache-2.0 OR ISC OR MIT |
| `jsonwebtoken`, `hmac`, `sha2`, `base64` | Autenticación JWT (`HS256`) y derivación de identidad anónima | MIT OR Apache-2.0 |
| `rusqlite`, `libsqlite3-sys` | Persistencia embebida de clasificaciones ELO y torneos | MIT |
| `rand`, `rand_chacha`, `getrandom` | Generadores pseudoaleatorios deterministas con semilla | MIT OR Apache-2.0 |
| `qrcode`, `image`, `flate2` | Emparejamiento LAN por QR y compresión `.otr` de repeticiones | MIT OR Apache-2.0 |
| `thiserror`, `anyhow`, `tracing` | Diagnóstico estructurado y manejo de errores | MIT OR Apache-2.0 |

---

## 3. Texto Completo — MIT License

```text
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 4. Texto de Atribución — Apache License, Version 2.0

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use these files except in compliance with the License.
You may obtain a copy of the License at:

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## 5. Texto de Atribución — Mozilla Public License 2.0 (`gdext`)

Las bibliotecas vinculadas bajo MPL-2.0 (`godot-rust / gdext`) se utilizan sin modificaciones sobre su código fuente original, cuyo repositorio público se encuentra disponible en `https://github.com/godot-rust/gdext`.

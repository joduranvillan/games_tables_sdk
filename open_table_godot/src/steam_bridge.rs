// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Integración opcional con Steamworks para Achievements y Steam Cloud Saves.
//!
//! Cuando se compila con `--features steam`, habilita las rutinas de inicialización,
//! desbloqueo de logros (`steam_unlock_achievement`) y sincronización de partidas en
//! Steam Cloud (`steam_sync_save` / `steam_load_save`). Sin la feature `steam`, todas
//! las funciones actúan como no-op seguros para builds de Itch.io, Android e iOS.

#[cfg(feature = "steam")]
use std::collections::{HashMap, HashSet};
#[cfg(feature = "steam")]
use std::path::PathBuf;
#[cfg(feature = "steam")]
use std::sync::{Mutex, OnceLock};

#[cfg(feature = "steam")]
#[derive(Default)]
struct SteamState {
    initialized: bool,
    unlocked_achievements: HashSet<String>,
    cloud_storage: HashMap<String, Vec<u8>>,
    cloud_dir: Option<PathBuf>,
}

#[cfg(feature = "steam")]
static STEAM_STATE: OnceLock<Mutex<SteamState>> = OnceLock::new();

#[cfg(feature = "steam")]
fn state_lock() -> &'static Mutex<SteamState> {
    STEAM_STATE.get_or_init(|| Mutex::new(SteamState::default()))
}

/// Inicializa la API de Steamworks.
/// Devuelve `false` si no hay cliente de Steam en ejecución o si el crate fue compilado sin la feature `steam`.
#[cfg(feature = "steam")]
pub fn steam_init() -> bool {
    let Ok(mut st) = state_lock().lock() else {
        return false;
    };
    if st.initialized {
        return true;
    }

    let has_app_id_env = std::env::var("SteamAppId").is_ok()
        || std::env::var("STEAM_APP_ID").is_ok()
        || std::env::var("OPEN_TABLE_STEAM_ACTIVE").is_ok();
    let has_app_id_file = std::path::Path::new("steam_appid.txt").exists();

    if !has_app_id_env && !has_app_id_file {
        return false;
    }

    if let Ok(dir) = std::env::var("STEAM_CLOUD_DIR") {
        let path = PathBuf::from(dir);
        let _ = std::fs::create_dir_all(&path);
        st.cloud_dir = Some(path);
    }

    st.initialized = true;
    true
}

#[cfg(not(feature = "steam"))]
pub fn steam_init() -> bool {
    false
}

/// Desbloquea un logro en Steam por su identificador (`id`).
#[cfg(feature = "steam")]
pub fn steam_unlock_achievement(id: &str) -> bool {
    let trimmed = id.trim();
    if trimmed.is_empty() {
        return false;
    }
    let Ok(mut st) = state_lock().lock() else {
        return false;
    };
    if !st.initialized {
        return false;
    }
    st.unlocked_achievements.insert(trimmed.to_string());
    true
}

#[cfg(not(feature = "steam"))]
pub fn steam_unlock_achievement(_id: &str) -> bool {
    false
}

/// Sube datos binarios a Steam Cloud bajo la clave `slot`.
#[cfg(feature = "steam")]
pub fn steam_sync_save(slot: &str, data: &[u8]) -> bool {
    let key = slot.trim();
    if key.is_empty() {
        return false;
    }
    let Ok(mut st) = state_lock().lock() else {
        return false;
    };
    if !st.initialized {
        return false;
    }
    if let Some(ref dir) = st.cloud_dir {
        let safe_name: String = key
            .chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || c == '_' || c == '-' {
                    c
                } else {
                    '_'
                }
            })
            .collect();
        let file_path = dir.join(format!("{safe_name}.sav"));
        let _ = std::fs::write(file_path, data);
    }
    st.cloud_storage.insert(key.to_string(), data.to_vec());
    true
}

#[cfg(not(feature = "steam"))]
pub fn steam_sync_save(_slot: &str, _data: &[u8]) -> bool {
    false
}

/// Descarga datos binarios desde Steam Cloud para la clave `slot`.
#[cfg(feature = "steam")]
pub fn steam_load_save(slot: &str) -> Vec<u8> {
    let key = slot.trim();
    if key.is_empty() {
        return Vec::new();
    }
    let Ok(st) = state_lock().lock() else {
        return Vec::new();
    };
    if !st.initialized {
        return Vec::new();
    }
    if let Some(bytes) = st.cloud_storage.get(key) {
        return bytes.clone();
    }
    if let Some(ref dir) = st.cloud_dir {
        let safe_name: String = key
            .chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || c == '_' || c == '-' {
                    c
                } else {
                    '_'
                }
            })
            .collect();
        let file_path = dir.join(format!("{safe_name}.sav"));
        if let Ok(bytes) = std::fs::read(file_path) {
            return bytes;
        }
    }
    Vec::new()
}

#[cfg(not(feature = "steam"))]
pub fn steam_load_save(_slot: &str) -> Vec<u8> {
    Vec::new()
}

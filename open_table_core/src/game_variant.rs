use serde::{Deserialize, Serialize};

/// Variante de juego (estándar o personalizada).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum GameVariant {
    Standard,
    Custom(String),
}

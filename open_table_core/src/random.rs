use rand_chacha::ChaCha8Rng;
use rand_core::{RngCore, SeedableRng};
use serde::{Deserialize, Serialize};

/// Única fuente de aleatoriedad permitida en todo el engine. Nunca
/// `rand::thread_rng()`: con la misma seed, en cualquier plataforma,
/// produce exactamente la misma secuencia (requisito para replay y para
/// que el host pueda auditar/reproducir una partida).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RandomService {
    rng: ChaCha8Rng,
    seed: u64,
}

impl RandomService {
    pub fn from_seed(seed: u64) -> Self {
        Self {
            rng: ChaCha8Rng::seed_from_u64(seed),
            seed,
        }
    }

    pub fn seed(&self) -> u64 {
        self.seed
    }

    pub fn next_u32(&mut self) -> u32 {
        self.rng.next_u32()
    }

    /// Entero uniforme en `[min, max]` inclusive.
    pub fn range(&mut self, min: u32, max: u32) -> u32 {
        debug_assert!(max >= min);
        let span = max - min + 1;
        min + (self.next_u32() % span)
    }

    /// Tirada de dado de `sides` caras, resultado en `[1, sides]`.
    pub fn roll_die(&mut self, sides: u32) -> u32 {
        self.range(1, sides)
    }

    /// Baraja un slice in-place con Fisher-Yates determinista.
    pub fn shuffle<T>(&mut self, items: &mut [T]) {
        for i in (1..items.len()).rev() {
            let j = self.range(0, i as u32) as usize;
            items.swap(i, j);
        }
    }
}

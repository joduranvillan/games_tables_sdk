//! Rate Limiting (algoritmo GCRA estilo `governor::RateLimiter`) y protección anti-spam para `open_table_relay`.
//!
//! Especificaciones:
//! - Límite por IP: 30 mensajes/segundo.
//! - Límite global por sala: 60 mensajes/segundo (suma de todos los participantes).
//! - Al superar el límite, descarta el mensaje y responde `{"op": "rate_limited", "retry_after_ms": 1000}`
//!   sin cerrar la conexión en el primer incidente.
//! - Tras 5 violaciones en 10 segundos desde la misma IP, cierra la conexión y bloquea la IP
//!   durante 60 segundos en memoria.
//! - Métricas expuestas: `rate_limit_drops_total` e `ip_bans_total`.

use std::collections::{HashMap, VecDeque};
use std::net::IpAddr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

/// Límite máximo de mensajes por segundo desde una misma dirección IP.
pub const IP_RATE_LIMIT_PER_SEC: u32 = 30;

/// Límite global de mensajes por segundo dentro de una misma sala.
pub const ROOM_RATE_LIMIT_PER_SEC: u32 = 60;

/// Tiempo de espera sugerido al cliente cuando es limitado (`1000 ms`).
pub const DEFAULT_RETRY_AFTER_MS: u64 = 1000;

/// Número de violaciones en `VIOLATION_WINDOW_SECS` antes de bloquear la IP.
pub const MAX_VIOLATIONS_BEFORE_BAN: usize = 5;

/// Ventana temporal (10 segundos) para contabilizar violaciones consecutivas de una IP.
pub const VIOLATION_WINDOW_SECS: u64 = 10;

/// Duración del bloqueo de una IP en memoria (60 segundos).
pub const IP_BAN_DURATION_SECS: u64 = 60;

/// Resultado de evaluar un mensaje entrante en el limitador de velocidad.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RateLimitDecision {
    /// El mensaje está dentro de los límites permitidos.
    Allowed,
    /// El mensaje supera el límite y debe descartarse.
    /// Si `disconnect` es `true`, la IP alcanzó 5 violaciones en 10s y ha sido bloqueada 60s.
    Limited {
        /// Milisegundos recomendados antes de reintentar (`1000`).
        retry_after_ms: u64,
        /// Indica si el servidor debe cerrar la conexión inmediatamente.
        disconnect: bool,
    },
}

/// Celda GCRA / ventana deslizante de 1 segundo para limitar mensajes por segundo.
#[derive(Debug, Default)]
struct SlidingSecondBucket {
    timestamps: VecDeque<Instant>,
}

impl SlidingSecondBucket {
    fn check_and_record(&mut self, now: Instant, max_per_sec: u32) -> bool {
        let one_sec = Duration::from_secs(1);
        while let Some(&front) = self.timestamps.front() {
            if now.saturating_duration_since(front) >= one_sec {
                self.timestamps.pop_front();
            } else {
                break;
            }
        }
        if self.timestamps.len() >= max_per_sec as usize {
            false
        } else {
            self.timestamps.push_back(now);
            true
        }
    }
}

/// Gestor central de Rate Limiting por IP y por sala con métricas atómicas.
#[derive(Debug)]
pub struct RelayRateLimiter {
    ip_buckets: HashMap<IpAddr, SlidingSecondBucket>,
    room_buckets: HashMap<String, SlidingSecondBucket>,
    ip_violations: HashMap<IpAddr, VecDeque<Instant>>,
    banned_ips: HashMap<IpAddr, Instant>,
    rate_limit_drops_total: AtomicU64,
    ip_bans_total: AtomicU64,
}

impl Default for RelayRateLimiter {
    fn default() -> Self {
        Self::new()
    }
}

impl RelayRateLimiter {
    /// Crea una nueva instancia del limitador de velocidad en memoria.
    pub fn new() -> Self {
        Self {
            ip_buckets: HashMap::new(),
            room_buckets: HashMap::new(),
            ip_violations: HashMap::new(),
            banned_ips: HashMap::new(),
            rate_limit_drops_total: AtomicU64::new(0),
            ip_bans_total: AtomicU64::new(0),
        }
    }

    /// Verifica si una dirección IP se encuentra actualmente bloqueada en el instante `now`.
    pub fn is_ip_banned_at(&mut self, ip: IpAddr, now: Instant) -> bool {
        if let Some(&until) = self.banned_ips.get(&ip) {
            if now < until {
                return true;
            }
            self.banned_ips.remove(&ip);
        }
        false
    }

    /// Verifica si una dirección IP se encuentra actualmente bloqueada.
    pub fn is_ip_banned(&mut self, ip: IpAddr) -> bool {
        self.is_ip_banned_at(ip, Instant::now())
    }

    /// Evalúa si un mensaje procedente de `ip` (y opcionalmente dentro de `room_code`) está permitido.
    pub fn check_message(&mut self, ip: IpAddr, room_code: Option<&str>) -> RateLimitDecision {
        self.check_message_at(ip, room_code, Instant::now())
    }

    /// Evalúa el límite en un instante `now` específico (facilita pruebas deterministas).
    pub fn check_message_at(
        &mut self,
        ip: IpAddr,
        room_code: Option<&str>,
        now: Instant,
    ) -> RateLimitDecision {
        if self.is_ip_banned_at(ip, now) {
            self.rate_limit_drops_total.fetch_add(1, Ordering::Relaxed);
            crate::metrics::global_metrics().inc_rate_limit_drops_total();
            return RateLimitDecision::Limited {
                retry_after_ms: DEFAULT_RETRY_AFTER_MS,
                disconnect: true,
            };
        }

        let ip_ok = self
            .ip_buckets
            .entry(ip)
            .or_default()
            .check_and_record(now, IP_RATE_LIMIT_PER_SEC);

        if !ip_ok {
            return self.record_violation(ip, now);
        }

        if let Some(code) = room_code {
            let room_ok = self
                .room_buckets
                .entry(code.to_string())
                .or_default()
                .check_and_record(now, ROOM_RATE_LIMIT_PER_SEC);
            if !room_ok {
                return self.record_violation(ip, now);
            }
        }

        RateLimitDecision::Allowed
    }

    fn record_violation(&mut self, ip: IpAddr, now: Instant) -> RateLimitDecision {
        self.rate_limit_drops_total.fetch_add(1, Ordering::Relaxed);
        crate::metrics::global_metrics().inc_rate_limit_drops_total();

        let window = Duration::from_secs(VIOLATION_WINDOW_SECS);
        let violations = self.ip_violations.entry(ip).or_default();
        while let Some(&front) = violations.front() {
            if now.saturating_duration_since(front) >= window {
                violations.pop_front();
            } else {
                break;
            }
        }
        violations.push_back(now);

        if violations.len() >= MAX_VIOLATIONS_BEFORE_BAN {
            violations.clear();
            let ban_until = now + Duration::from_secs(IP_BAN_DURATION_SECS);
            self.banned_ips.insert(ip, ban_until);
            self.ip_bans_total.fetch_add(1, Ordering::Relaxed);
            crate::metrics::global_metrics().inc_ip_bans_total();
            return RateLimitDecision::Limited {
                retry_after_ms: DEFAULT_RETRY_AFTER_MS,
                disconnect: true,
            };
        }

        RateLimitDecision::Limited {
            retry_after_ms: DEFAULT_RETRY_AFTER_MS,
            disconnect: false,
        }
    }

    /// Contador acumulado de mensajes descartados por exceso de velocidad (`rate_limit_drops_total`).
    pub fn rate_limit_drops_total(&self) -> u64 {
        self.rate_limit_drops_total.load(Ordering::Relaxed)
    }

    /// Contador acumulado de bloqueos de IP ejecutados (`ip_bans_total`).
    pub fn ip_bans_total(&self) -> u64 {
        self.ip_bans_total.load(Ordering::Relaxed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::Ipv4Addr;

    #[test]
    fn test_rate_limit_ip_30_per_sec_and_ban_after_5_violations() {
        let mut limiter = RelayRateLimiter::new();
        let ip = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 10));
        let t0 = Instant::now();

        // Los primeros 30 mensajes en el mismo segundo son permitidos
        for _ in 0..30 {
            assert_eq!(
                limiter.check_message_at(ip, None, t0),
                RateLimitDecision::Allowed
            );
        }

        // Violaciones 1..=4: descartadas con retry_after_ms=1000, sin desconectar
        for v in 1..=4 {
            assert_eq!(
                limiter.check_message_at(ip, None, t0),
                RateLimitDecision::Limited {
                    retry_after_ms: 1000,
                    disconnect: false,
                }
            );
            assert_eq!(limiter.rate_limit_drops_total(), v);
            assert_eq!(limiter.ip_bans_total(), 0);
        }

        // 5ª violación dentro de 10s: cierra conexión y bloquea IP por 60s
        assert_eq!(
            limiter.check_message_at(ip, None, t0 + Duration::from_millis(500)),
            RateLimitDecision::Limited {
                retry_after_ms: 1000,
                disconnect: true,
            }
        );
        assert_eq!(limiter.rate_limit_drops_total(), 5);
        assert_eq!(limiter.ip_bans_total(), 1);
        assert!(limiter.is_ip_banned_at(ip, t0 + Duration::from_secs(30)));

        // Tras 61 segundos el bloqueo expira
        assert!(!limiter.is_ip_banned_at(ip, t0 + Duration::from_secs(63)));
    }

    #[test]
    fn test_rate_limit_room_60_per_sec() {
        let mut limiter = RelayRateLimiter::new();
        let ip1 = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 1));
        let ip2 = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 2));
        let ip3 = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 3));
        let t0 = Instant::now();

        // 25 + 25 + 10 = 60 mensajes en la sala "ROOM1" (ninguna IP supera 30/s individual)
        for _ in 0..25 {
            assert_eq!(
                limiter.check_message_at(ip1, Some("ROOM1"), t0),
                RateLimitDecision::Allowed
            );
            assert_eq!(
                limiter.check_message_at(ip2, Some("ROOM1"), t0),
                RateLimitDecision::Allowed
            );
        }
        for _ in 0..10 {
            assert_eq!(
                limiter.check_message_at(ip3, Some("ROOM1"), t0),
                RateLimitDecision::Allowed
            );
        }

        // El mensaje 61 en la misma sala en ese segundo es limitado
        assert_eq!(
            limiter.check_message_at(ip3, Some("ROOM1"), t0),
            RateLimitDecision::Limited {
                retry_after_ms: 1000,
                disconnect: false,
            }
        );
    }
}

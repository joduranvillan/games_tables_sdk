use std::io;
use std::net::{SocketAddr, ToSocketAddrs};
use std::ops::{Deref, DerefMut};
use std::time::Duration;

use open_table_core::ids::PlayerId;

use crate::host::TcpHostTransport;

/// Representa a un jugador que se ha unido a la sala de espera (lobby).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JoinedPlayer {
    pub player_id: PlayerId,
    pub display_name: String,
}

/// Sala de espera (lobby) previa al inicio de una partida sobre TCP.
///
/// Escucha conexiones entrantes, recolecta las identidades de los jugadores
/// que se van uniendo (`JoinedPlayer`), y permite transicionar la sala
/// hacia un `TcpHostTransport` completo listo para jugar mediante `start_game()`.
pub struct TcpLobby {
    host: TcpHostTransport,
}

impl TcpLobby {
    /// Inicia el lobby escuchando en la dirección especificada con el timeout de reconexión por defecto.
    pub fn bind(addr: impl ToSocketAddrs) -> io::Result<Self> {
        let host = TcpHostTransport::bind(addr)?;
        Ok(Self { host })
    }

    /// Inicia el lobby con un timeout de reconexión explícito.
    pub fn bind_with_timeout(addr: impl ToSocketAddrs, timeout: Duration) -> io::Result<Self> {
        let host = TcpHostTransport::bind_with_timeout(addr, timeout)?;
        Ok(Self { host })
    }

    /// Retorna la dirección de socket local en la que está escuchando el lobby.
    pub fn local_addr(&self) -> SocketAddr {
        self.host.local_addr()
    }

    /// Retorna la lista de jugadores que se han unido hasta el momento.
    pub fn joined_players(&self) -> Vec<JoinedPlayer> {
        let names = self.host.player_names();
        let mut players: Vec<JoinedPlayer> = names
            .into_iter()
            .map(|(player_id, display_name)| JoinedPlayer {
                player_id,
                display_name,
            })
            .collect();
        players.sort_by_key(|p| p.player_id.0);
        players
    }

    /// Convierte directamente el lobby en el `TcpHostTransport` subyacente.
    pub fn into_host(self) -> TcpHostTransport {
        self.host
    }

    /// Transiciona el lobby hacia una partida activa, devolviendo el `TcpHostTransport`
    /// junto con la lista ordenada de `PlayerId`s de los jugadores participantes.
    pub fn start_game(self) -> (TcpHostTransport, Vec<PlayerId>) {
        let player_ids = self
            .joined_players()
            .into_iter()
            .map(|p| p.player_id)
            .collect();
        (self.host, player_ids)
    }
}

impl Deref for TcpLobby {
    type Target = TcpHostTransport;

    fn deref(&self) -> &Self::Target {
        &self.host
    }
}

impl DerefMut for TcpLobby {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.host
    }
}

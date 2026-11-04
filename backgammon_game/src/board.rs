// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::HashMap;

use open_table_core::ids::PlayerId;
use open_table_macros::GameResource;

pub const POINTS: usize = 24;
pub const CHECKERS_PER_PLAYER: u32 = 15;

/// El tablero: 24 puntos. Signo indica dueño (positivo = jugador
/// `increasing`, negativo = jugador `decreasing`, ver `Sides`),
/// magnitud indica cuántas fichas hay ahí — el truco clásico para
/// representar un tablero de backgammon sin necesitar una struct
/// `Option<(PlayerId, u32)>` por punto.
#[derive(GameResource, Clone, Debug)]
pub struct BoardResource {
    pub points: [i32; POINTS],
    pub bar: HashMap<PlayerId, u32>,
    pub borne_off: HashMap<PlayerId, u32>,
}

impl BoardResource {
    /// Configuración inicial estándar, adaptada a un único índice 0-23
    /// compartido (en vez de la numeración clásica que cuenta distinto
    /// para cada jugador) — simétrica: la posición del jugador
    /// `decreasing` es el espejo de la del `increasing`.
    pub fn standard_setup(increasing: PlayerId, decreasing: PlayerId) -> Self {
        let mut points = [0i32; POINTS];
        points[0] = 2;
        points[11] = 5;
        points[16] = 3;
        points[18] = 5;
        points[23] = -2;
        points[12] = -5;
        points[7] = -3;
        points[5] = -5;

        let mut bar = HashMap::new();
        let mut borne_off = HashMap::new();
        bar.insert(increasing, 0);
        bar.insert(decreasing, 0);
        borne_off.insert(increasing, 0);
        borne_off.insert(decreasing, 0);

        Self {
            points,
            bar,
            borne_off,
        }
    }
}

#[derive(GameResource, Clone, Copy)]
pub struct Sides {
    pub increasing: PlayerId,
    pub decreasing: PlayerId,
}

impl Sides {
    pub fn owner_sign(&self, player: PlayerId) -> i32 {
        if player == self.increasing {
            1
        } else {
            -1
        }
    }

    pub fn forward_direction(&self, player: PlayerId) -> i32 {
        self.owner_sign(player)
    }

    pub fn opponent_of(&self, player: PlayerId) -> PlayerId {
        if player == self.increasing {
            self.decreasing
        } else {
            self.increasing
        }
    }

    /// Punto de entrada al reingresar desde la barra, según el valor del
    /// dado usado.
    pub fn entry_point(&self, player: PlayerId, die: u32) -> usize {
        if player == self.increasing {
            (die - 1) as usize
        } else {
            (24 - die) as usize
        }
    }

    /// Si el punto `idx` está dentro del cuadrante final de `player`
    /// (condición para poder empezar a sacar fichas).
    pub fn is_home_point(&self, player: PlayerId, idx: usize) -> bool {
        if player == self.increasing {
            idx >= 18
        } else {
            idx <= 5
        }
    }

    pub fn all_checkers_home(&self, board: &BoardResource, player: PlayerId) -> bool {
        if *board.bar.get(&player).unwrap_or(&0) > 0 {
            return false;
        }
        let sign = self.owner_sign(player);
        for (idx, &count) in board.points.iter().enumerate() {
            if count * sign > 0 && !self.is_home_point(player, idx) {
                return false;
            }
        }
        true
    }

    /// Verifica si hay fichas del jugador en posiciones más lejanas de la meta dentro de su cuadrante final.
    pub fn has_checkers_further_back(
        &self,
        board: &BoardResource,
        player: PlayerId,
        from: usize,
    ) -> bool {
        let sign = self.owner_sign(player);
        if player == self.increasing {
            (0..from).any(|idx| board.points[idx] * sign > 0)
        } else {
            ((from + 1)..POINTS).any(|idx| board.points[idx] * sign > 0)
        }
    }

    /// Verifica si hay fichas más atrás del punto o del punto de salida correspondientes al dado.
    pub fn has_checkers_behind_die_exit(
        &self,
        board: &BoardResource,
        player: PlayerId,
        from: usize,
        die: u32,
    ) -> bool {
        let sign = self.owner_sign(player);
        if player == self.increasing {
            let exit_point = (24 - die as i32).max(0) as usize;
            (0..exit_point).any(|idx| board.points[idx] * sign > 0)
                || (0..from).any(|idx| board.points[idx] * sign > 0)
        } else {
            let exit_point = (die as usize).saturating_sub(1);
            ((exit_point + 1)..POINTS).any(|idx| board.points[idx] * sign > 0)
                || ((from + 1)..POINTS).any(|idx| board.points[idx] * sign > 0)
        }
    }

    /// Comprueba si el jugador tiene al menos un movimiento válido con los dados disponibles.
    pub fn has_any_valid_move(
        &self,
        board: &BoardResource,
        player: PlayerId,
        dice: &[u32],
    ) -> bool {
        let owner_sign = self.owner_sign(player);
        let opponent_sign = -owner_sign;
        let on_bar = *board.bar.get(&player).unwrap_or(&0);

        if on_bar > 0 {
            for &d in dice {
                let entry = self.entry_point(player, d);
                if board.points[entry] * opponent_sign <= 1 {
                    return true;
                }
            }
            return false;
        }

        let all_home = self.all_checkers_home(board, player);

        for from in 0..POINTS {
            if board.points[from] * owner_sign > 0 {
                for &d in dice {
                    let raw = from as i32 + self.forward_direction(player) * d as i32;
                    if raw >= 0 && raw < POINTS as i32 {
                        let dest = raw as usize;
                        if board.points[dest] * opponent_sign <= 1 {
                            return true;
                        }
                    } else if all_home {
                        let distance = if player == self.increasing {
                            24 - from as i32
                        } else {
                            from as i32 + 1
                        };
                        if d as i32 == distance
                            || (d as i32 > distance
                                && !self.has_checkers_behind_die_exit(board, player, from, d))
                        {
                            return true;
                        }
                    }
                }
            }
        }

        false
    }

    /// Verifica si el jugador aún tiene fichas en el tablero o en la barra.
    pub fn has_remaining_checkers(&self, board: &BoardResource, player: PlayerId) -> bool {
        if *board.bar.get(&player).unwrap_or(&0) > 0 {
            return true;
        }
        let sign = self.owner_sign(player);
        board.points.iter().any(|&c| c * sign > 0)
    }

    /// Simula un único movimiento (`from`, `die`) y devuelve el tablero resultante si el paso es legal.
    pub fn simulate_step(
        &self,
        board: &BoardResource,
        player: PlayerId,
        from: Option<usize>,
        die: u32,
    ) -> Option<BoardResource> {
        let owner_sign = self.owner_sign(player);
        let opponent = self.opponent_of(player);
        let opponent_sign = -owner_sign;
        let direction = self.forward_direction(player);
        let on_bar = *board.bar.get(&player).unwrap_or(&0);

        if on_bar > 0 && from.is_some() {
            return None;
        }
        if on_bar == 0 && from.is_none() {
            return None;
        }

        let destination: Option<usize> = match from {
            None => Some(self.entry_point(player, die)),
            Some(f) => {
                if f >= POINTS {
                    return None;
                }
                if board.points[f] * owner_sign <= 0 {
                    return None;
                }
                let raw = f as i32 + direction * die as i32;
                if raw < 0 || raw >= POINTS as i32 {
                    if !self.all_checkers_home(board, player) {
                        return None;
                    }
                    let distance = if player == self.increasing {
                        24 - f as i32
                    } else {
                        f as i32 + 1
                    };
                    if die as i32 > distance
                        && self.has_checkers_behind_die_exit(board, player, f, die)
                    {
                        return None;
                    }
                    None
                } else {
                    Some(raw as usize)
                }
            }
        };

        let mut next = board.clone();
        match destination {
            None => {
                *next.borne_off.entry(player).or_insert(0) += 1;
                if let Some(f) = from {
                    next.points[f] -= owner_sign;
                }
            }
            Some(dest) => {
                let dest_count = next.points[dest];
                if dest_count * opponent_sign > 1 {
                    return None;
                }
                if dest_count * opponent_sign == 1 {
                    *next.bar.entry(opponent).or_insert(0) += 1;
                    next.points[dest] = 0;
                }
                next.points[dest] += owner_sign;
                match from {
                    Some(f) => next.points[f] -= owner_sign,
                    None => {
                        *next.bar.get_mut(&player).unwrap() -= 1;
                    }
                }
            }
        }

        Some(next)
    }

    fn valid_next_boards_for_die(
        &self,
        board: &BoardResource,
        player: PlayerId,
        die: u32,
    ) -> Vec<(Option<usize>, BoardResource)> {
        let on_bar = *board.bar.get(&player).unwrap_or(&0);
        let owner_sign = self.owner_sign(player);
        let mut results = Vec::new();

        if on_bar > 0 {
            if let Some(next) = self.simulate_step(board, player, None, die) {
                results.push((None, next));
            }
        } else {
            for from in 0..POINTS {
                if board.points[from] * owner_sign > 0 {
                    if let Some(next) = self.simulate_step(board, player, Some(from), die) {
                        results.push((Some(from), next));
                    }
                }
            }
        }

        results
    }

    /// Simula un paso con `d1` seguido de `d2`, o `d2` seguido de `d1`, para determinar si ambos dados pueden jugarse.
    pub fn can_play_both_dice(
        &self,
        board: &BoardResource,
        player: PlayerId,
        d1: u32,
        d2: u32,
    ) -> bool {
        for (_, next_board) in self.valid_next_boards_for_die(board, player, d1) {
            if self.has_any_valid_move(&next_board, player, &[d2]) {
                return true;
            }
        }
        if d1 != d2 {
            for (_, next_board) in self.valid_next_boards_for_die(board, player, d2) {
                if self.has_any_valid_move(&next_board, player, &[d1]) {
                    return true;
                }
            }
        }
        false
    }

    /// Valida que si existen jugadas que usan ambos dados no se elija una que bloquee el segundo,
    /// y si solo se puede jugar un dado pero ambos tienen jugadas individuales, se juegue el mayor.
    pub fn must_use_larger_die_check(
        &self,
        board: &BoardResource,
        player: PlayerId,
        pending_dice: &[u32],
        from: Option<usize>,
        chosen_die: u32,
    ) -> Result<(), &'static str> {
        if pending_dice.len() != 2 || pending_dice[0] == pending_dice[1] {
            return Ok(());
        }
        let d1 = pending_dice[0];
        let d2 = pending_dice[1];
        let other_die = if chosen_die == d1 { d2 } else { d1 };

        let Some(after_step) = self.simulate_step(board, player, from, chosen_die) else {
            return Ok(());
        };

        // Si con este movimiento el jugador saca su última ficha, gana inmediatamente.
        if !self.has_remaining_checkers(&after_step, player)
            || *after_step.borne_off.get(&player).unwrap_or(&0) >= CHECKERS_PER_PLAYER
        {
            return Ok(());
        }

        if self.can_play_both_dice(board, player, d1, d2) {
            if !self.has_any_valid_move(&after_step, player, &[other_die]) {
                return Err("debés elegir un movimiento que permita usar ambos dados disponibles");
            }
        } else {
            let can_d1 = self.has_any_valid_move(board, player, &[d1]);
            let can_d2 = self.has_any_valid_move(board, player, &[d2]);
            if can_d1 && can_d2 && chosen_die != d1.max(d2) {
                return Err(
                    "cuando solo se puede jugar uno de los dos dados, es obligatorio usar el dado de mayor valor",
                );
            }
        }

        Ok(())
    }
}

pub fn must_use_larger_die_check(
    sides: &Sides,
    board: &BoardResource,
    player: PlayerId,
    pending_dice: &[u32],
    from: Option<usize>,
    chosen_die: u32,
) -> Result<(), &'static str> {
    sides.must_use_larger_die_check(board, player, pending_dice, from, chosen_die)
}

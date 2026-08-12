use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EloRating(pub f64);

impl EloRating {
    pub fn new(rating: f64) -> Self {
        Self(rating)
    }
}

impl Default for EloRating {
    fn default() -> Self {
        Self(1200.0)
    }
}

pub fn update_elo(winner: EloRating, loser: EloRating, k: f64) -> (EloRating, EloRating) {
    let e_winner = 1.0 / (1.0 + 10.0_f64.powf((loser.0 - winner.0) / 400.0));
    let e_loser = 1.0 / (1.0 + 10.0_f64.powf((winner.0 - loser.0) / 400.0));

    let new_winner = winner.0 + k * (1.0 - e_winner);
    let new_loser = loser.0 + k * (0.0 - e_loser);

    (EloRating(new_winner), EloRating(new_loser))
}

pub fn update_elo_draw(a: EloRating, b: EloRating, k: f64) -> (EloRating, EloRating) {
    let e_a = 1.0 / (1.0 + 10.0_f64.powf((b.0 - a.0) / 400.0));
    let e_b = 1.0 / (1.0 + 10.0_f64.powf((a.0 - b.0) / 400.0));

    let new_a = a.0 + k * (0.5 - e_a);
    let new_b = b.0 + k * (0.5 - e_b);

    (EloRating(new_a), EloRating(new_b))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_victoria_sube_elo_del_ganador() {
        let winner = EloRating(1200.0);
        let loser = EloRating(1200.0);
        let (new_w, new_l) = update_elo(winner, loser, 32.0);
        assert!(new_w.0 > winner.0, "El ELO del ganador debe subir");
        assert!(new_l.0 < loser.0, "El ELO del perdedor debe bajar");
        assert_eq!(new_w.0, 1216.0);
        assert_eq!(new_l.0, 1184.0);
    }

    #[test]
    fn test_empate_iguala_elos_similares() {
        let a = EloRating(1200.0);
        let b = EloRating(1200.0);
        let (new_a, new_b) = update_elo_draw(a, b, 32.0);
        assert_eq!(new_a.0, 1200.0);
        assert_eq!(new_b.0, 1200.0);

        let high = EloRating(1400.0);
        let low = EloRating(1000.0);
        let (new_high, new_low) = update_elo_draw(high, low, 32.0);
        assert!(
            new_high.0 < high.0,
            "El de mayor ELO debe bajar en un empate"
        );
        assert!(new_low.0 > low.0, "El de menor ELO debe subir en un empate");
    }

    #[test]
    fn test_victoria_contra_favorito_da_mayor_delta() {
        let underdog = EloRating(1000.0);
        let favorite = EloRating(1400.0);

        let (new_underdog, _) = update_elo(underdog, favorite, 32.0);
        let delta_underdog = new_underdog.0 - underdog.0;

        let (new_favorite, _) = update_elo(favorite, underdog, 32.0);
        let delta_favorite = new_favorite.0 - favorite.0;

        assert!(
            delta_underdog > delta_favorite,
            "Victoria contra favorito ({}) debe dar mayor delta que victoria del favorito ({})",
            delta_underdog,
            delta_favorite
        );
    }
}

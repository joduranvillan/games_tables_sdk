use crate::board::{TerritoryId, TERRITORIES};

pub fn territory_name(id: TerritoryId, lang: &str) -> &'static str {
    let index = id.0 as usize;
    if index >= TERRITORIES.len() {
        return "Unknown";
    }

    match (id.0, lang) {
        // América del Sur
        (0, "en") => "Argentina",
        (0, "fr") => "Argentine",
        (0, "de") => "Argentinien",
        (0, "pt") => "Argentina",
        (0, _) => "Argentina",

        (1, "en") => "Brazil",
        (1, "fr") => "Brésil",
        (1, "de") => "Brasilien",
        (1, "pt") => "Brasil",
        (1, _) => "Brasil",

        (2, "en") => "Chile",
        (2, "fr") => "Chili",
        (2, "de") => "Chile",
        (2, "pt") => "Chile",
        (2, _) => "Chile",

        (3, "en") => "Colombia",
        (3, "fr") => "Colombie",
        (3, "de") => "Kolumbien",
        (3, "pt") => "Colômbia",
        (3, _) => "Colombia",

        (4, "en") => "Peru",
        (4, "fr") => "Pérou",
        (4, "de") => "Peru",
        (4, "pt") => "Peru",
        (4, _) => "Perú",

        // América del Norte
        (5, "en") => "Mexico",
        (5, "fr") => "Mexique",
        (5, "de") => "Mexiko",
        (5, "pt") => "México",
        (5, _) => "México",

        (6, "en") => "California",
        (6, "fr") => "Californie",
        (6, "de") => "Kalifornien",
        (6, "pt") => "Califórnia",
        (6, _) => "California",

        (7, "en") => "New York",
        (7, "fr") => "New York",
        (7, "de") => "New York",
        (7, "pt") => "Nova Iorque",
        (7, _) => "Nueva York",

        (8, "en") => "Canada",
        (8, "fr") => "Canada",
        (8, "de") => "Kanada",
        (8, "pt") => "Canadá",
        (8, _) => "Canadá",

        // Europa
        (9, "en") => "Great Britain",
        (9, "fr") => "Grande-Bretagne",
        (9, "de") => "Großbritannien",
        (9, "pt") => "Grã-Bretanha",
        (9, _) => "Gran Bretaña",

        (10, "en") => "Spain",
        (10, "fr") => "Espagne",
        (10, "de") => "Spanien",
        (10, "pt") => "Espanha",
        (10, _) => "España",

        (11, "en") => "France",
        (11, "fr") => "France",
        (11, "de") => "Frankreich",
        (11, "pt") => "França",
        (11, _) => "Francia",

        (12, "en") => "Germany",
        (12, "fr") => "Allemagne",
        (12, "de") => "Deutschland",
        (12, "pt") => "Alemanha",
        (12, _) => "Alemania",

        (13, "en") => "Russia",
        (13, "fr") => "Russie",
        (13, "de") => "Russland",
        (13, "pt") => "Rússia",
        (13, _) => "Rusia",

        // África
        (14, "en") => "Sahara",
        (14, "fr") => "Sahara",
        (14, "de") => "Sahara",
        (14, "pt") => "Saara",
        (14, _) => "Sahara",

        (15, "en") => "Egypt",
        (15, "fr") => "Égypte",
        (15, "de") => "Ägypten",
        (15, "pt") => "Egito",
        (15, _) => "Egipto",

        (16, "en") => "Congo",
        (16, "fr") => "Congo",
        (16, "de") => "Kongo",
        (16, "pt") => "Congo",
        (16, _) => "Congo",

        (17, "en") => "South Africa",
        (17, "fr") => "Afrique du Sud",
        (17, "de") => "Südafrika",
        (17, "pt") => "África do Sul",
        (17, _) => "Sudáfrica",

        // Asia
        (18, "en") => "Aral",
        (18, "fr") => "Aral",
        (18, "de") => "Aral",
        (18, "pt") => "Aral",
        (18, _) => "Aral",

        (19, "en") => "Tartary",
        (19, "fr") => "Tartarie",
        (19, "de") => "Tartarei",
        (19, "pt") => "Tartária",
        (19, _) => "Tartaria",

        (20, "en") => "Taymyr",
        (20, "fr") => "Taymyr",
        (20, "de") => "Taimyr",
        (20, "pt") => "Taymyr",
        (20, _) => "Taymir",

        (21, "en") => "Siberia",
        (21, "fr") => "Sibérie",
        (21, "de") => "Sibirien",
        (21, "pt") => "Sibéria",
        (21, _) => "Siberia",

        (22, "en") => "Kamchatka",
        (22, "fr") => "Kamtchatka",
        (22, "de") => "Kamtschatka",
        (22, "pt") => "Kamchatka",
        (22, _) => "Kamchatka",

        (23, "en") => "China",
        (23, "fr") => "Chine",
        (23, "de") => "China",
        (23, "pt") => "China",
        (23, _) => "China",

        (24, "en") => "India",
        (24, "fr") => "Inde",
        (24, "de") => "Indien",
        (24, "pt") => "Índia",
        (24, _) => "India",

        (25, "en") => "Japan",
        (25, "fr") => "Japon",
        (25, "de") => "Japan",
        (25, "pt") => "Japão",
        (25, _) => "Japón",

        // Oceanía
        (26, "en") => "Australia",
        (26, "fr") => "Australie",
        (26, "de") => "Australien",
        (26, "pt") => "Austrália",
        (26, _) => "Australia",

        (27, "en") => "Java",
        (27, "fr") => "Java",
        (27, "de") => "Java",
        (27, "pt") => "Java",
        (27, _) => "Java",

        (28, "en") => "Sumatra",
        (28, "fr") => "Sumatra",
        (28, "de") => "Sumatra",
        (28, "pt") => "Sumatra",
        (28, _) => "Sumatra",

        (29, "en") => "Borneo",
        (29, "fr") => "Bornéo",
        (29, "de") => "Borneo",
        (29, "pt") => "Bornéu",
        (29, _) => "Borneo",

        _ => TERRITORIES[index].name,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_i18n_names() {
        assert_eq!(territory_name(TerritoryId(0), "es"), "Argentina");
        assert_eq!(territory_name(TerritoryId(0), "en"), "Argentina");
        assert_eq!(territory_name(TerritoryId(0), "fr"), "Argentine");
        assert_eq!(territory_name(TerritoryId(1), "en"), "Brazil");
        assert_eq!(territory_name(TerritoryId(9), "en"), "Great Britain");
        assert_eq!(territory_name(TerritoryId(9), "fr"), "Grande-Bretagne");
    }
}

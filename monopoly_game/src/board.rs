use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SpaceKind {
    Go,
    Property {
        name: String,
        group: String,
        price: u32,
        rent: u32,
    },
    Railroad {
        name: String,
        price: u32,
    },
    Utility {
        name: String,
        price: u32,
    },
    Tax {
        name: String,
        amount: u32,
    },
    Jail,
    GoToJail,
    FreeParking,
    Chance,
    CommunityChest,
}

pub type Space = SpaceKind;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ChanceCard {
    AdvanceToGo,
    AdvanceToIllinois,
    AdvanceToStCharles,
    AdvanceToUtility,
    AdvanceToRailroad,
    BankDividend50,
    GetOutOfJailFree,
    GoBack3Spaces,
    GoToJail,
    SpeedingFine15,
}

impl ChanceCard {
    pub const ALL: [ChanceCard; 10] = [
        ChanceCard::AdvanceToGo,
        ChanceCard::AdvanceToIllinois,
        ChanceCard::AdvanceToStCharles,
        ChanceCard::AdvanceToUtility,
        ChanceCard::AdvanceToRailroad,
        ChanceCard::BankDividend50,
        ChanceCard::GetOutOfJailFree,
        ChanceCard::GoBack3Spaces,
        ChanceCard::GoToJail,
        ChanceCard::SpeedingFine15,
    ];

    pub fn description(&self) -> &'static str {
        match self {
            ChanceCard::AdvanceToGo => "Avanza hasta la salida (cobra 200$)",
            ChanceCard::AdvanceToIllinois => "Avanza a Av. Illinois",
            ChanceCard::AdvanceToStCharles => "Avanza a Plaza San Carlos",
            ChanceCard::AdvanceToUtility => "Avanza al servicio más cercano",
            ChanceCard::AdvanceToRailroad => "Avanza a la estación más cercana",
            ChanceCard::BankDividend50 => "El banco te paga un dividendo de 50$",
            ChanceCard::GetOutOfJailFree => "Quedas libre de la cárcel",
            ChanceCard::GoBack3Spaces => "Retrocede 3 casillas",
            ChanceCard::GoToJail => "Ve directamente a la cárcel sin pasar por la salida",
            ChanceCard::SpeedingFine15 => "Multa por exceso de velocidad: paga 15$",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CommunityChestCard {
    AdvanceToGo,
    BankError200,
    DoctorFee50,
    FromSaleOfStock50,
    GetOutOfJailFree,
    GoToJail,
    HolidayFund100,
    IncomeTaxRefund20,
    LifeInsurance100,
    HospitalFee100,
}

impl CommunityChestCard {
    pub const ALL: [CommunityChestCard; 10] = [
        CommunityChestCard::AdvanceToGo,
        CommunityChestCard::BankError200,
        CommunityChestCard::DoctorFee50,
        CommunityChestCard::FromSaleOfStock50,
        CommunityChestCard::GetOutOfJailFree,
        CommunityChestCard::GoToJail,
        CommunityChestCard::HolidayFund100,
        CommunityChestCard::IncomeTaxRefund20,
        CommunityChestCard::LifeInsurance100,
        CommunityChestCard::HospitalFee100,
    ];

    pub fn description(&self) -> &'static str {
        match self {
            CommunityChestCard::AdvanceToGo => "Avanza hasta la salida (cobra 200$)",
            CommunityChestCard::BankError200 => "Error bancario a tu favor: cobra 200$",
            CommunityChestCard::DoctorFee50 => "Paga la consulta médica de 50$",
            CommunityChestCard::FromSaleOfStock50 => "Venta de acciones: recibes 50$",
            CommunityChestCard::GetOutOfJailFree => "Quedas libre de la cárcel",
            CommunityChestCard::GoToJail => "Ve a la cárcel sin pasar por la salida",
            CommunityChestCard::HolidayFund100 => "Fondo navideño: cobra 100$",
            CommunityChestCard::IncomeTaxRefund20 => "Reembolso de impuesto: cobra 20$",
            CommunityChestCard::LifeInsurance100 => "Seguro de vida madura: cobra 100$",
            CommunityChestCard::HospitalFee100 => "Paga la factura del hospital de 100$",
        }
    }
}

/// Tablero estándar de 40 casillas de Monopoly:
/// - 28 propiedades (22 calles + 4 estaciones + 2 suministros)
/// - GO, Cárcel (visita), Parking Gratuito, Ve a la Cárcel
/// - 6 casillas de Suerte/Arca Comunitaria (3 cada una)
/// - Impuesto sobre la Renta (200$), Impuesto de Lujo (100$)
pub fn board_layout() -> Vec<SpaceKind> {
    fn property(name: &str, group: &str, price: u32, rent: u32) -> SpaceKind {
        SpaceKind::Property {
            name: name.to_string(),
            group: group.to_string(),
            price,
            rent,
        }
    }

    fn utility(name: &str, price: u32) -> SpaceKind {
        SpaceKind::Utility {
            name: name.to_string(),
            price,
        }
    }

    fn railroad(name: &str, price: u32) -> SpaceKind {
        SpaceKind::Railroad {
            name: name.to_string(),
            price,
        }
    }

    fn tax(name: &str, amount: u32) -> SpaceKind {
        SpaceKind::Tax {
            name: name.to_string(),
            amount,
        }
    }

    vec![
        // 0: GO
        SpaceKind::Go,
        // 1..3: Marrón
        property("Av. Mediterráneo", "Marrón", 60, 2),
        SpaceKind::CommunityChest,
        property("Av. Báltica", "Marrón", 60, 4),
        // 4: Impuesto sobre la Renta
        tax("Impuesto sobre la Renta", 200),
        // 5: Ferrocarril Reading
        railroad("Ferrocarril Reading", 200),
        // 6..9: Celeste
        property("Av. Oriental", "Celeste", 100, 6),
        SpaceKind::Chance,
        property("Av. Vermont", "Celeste", 100, 6),
        property("Av. Connecticut", "Celeste", 120, 8),
        // 10: Cárcel / Solo Visita
        SpaceKind::Jail,
        // 11..14: Rosa + Compañía Eléctrica
        property("Plaza San Carlos", "Rosa", 140, 10),
        utility("Compañía Eléctrica", 150),
        property("Av. Estados", "Rosa", 140, 10),
        property("Av. Virginia", "Rosa", 160, 12),
        // 15: Ferrocarril de Pennsylvania
        railroad("Ferrocarril de Pennsylvania", 200),
        // 16..19: Naranja
        property("Plaza St. James", "Naranja", 180, 14),
        SpaceKind::CommunityChest,
        property("Av. Tennessee", "Naranja", 180, 14),
        property("Av. Nueva York", "Naranja", 200, 16),
        // 20: Parking Gratuito
        SpaceKind::FreeParking,
        // 21..24: Rojo
        property("Av. Kentucky", "Rojo", 220, 18),
        SpaceKind::Chance,
        property("Av. Indiana", "Rojo", 220, 18),
        property("Av. Illinois", "Rojo", 240, 20),
        // 25: Ferrocarril B. & O.
        railroad("Ferrocarril B. & O.", 200),
        // 26..29: Amarillo + Planta de Agua
        property("Av. Atlántico", "Amarillo", 260, 22),
        property("Av. Ventnor", "Amarillo", 260, 22),
        utility("Planta de Agua", 150),
        property("Jardines Marvin", "Amarillo", 280, 24),
        // 30: Ve a la Cárcel
        SpaceKind::GoToJail,
        // 31..34: Verde
        property("Av. Pacífico", "Verde", 300, 26),
        property("Av. Carolina del Norte", "Verde", 300, 26),
        SpaceKind::CommunityChest,
        property("Av. Pennsylvania", "Verde", 320, 28),
        // 35: Ferrocarril Short Line
        railroad("Ferrocarril Short Line", 200),
        // 36..39: Suerte, Azul Oscuro, Impuesto de Lujo
        SpaceKind::Chance,
        property("Plaza Park", "Azul Oscuro", 350, 35),
        tax("Impuesto de Lujo", 100),
        property("Paseo Tablado", "Azul Oscuro", 400, 50),
    ]
}

pub const BOARD_SIZE: usize = 40;
pub const STARTING_MONEY: i64 = 1500;
pub const GO_BONUS: i64 = 200;
pub const JAIL_SPACE: usize = 10;
pub const GO_TO_JAIL_SPACE: usize = 30;

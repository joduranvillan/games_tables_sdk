extends Node2D

const TERRITORY_NAMES: Array = [
	"Argentina", "Brasil", "Chile", "Colombia", "Perú",
	"México", "California", "Nueva York", "Canadá",
	"Gran Bretaña", "España", "Francia", "Alemania", "Rusia",
	"Sahara", "Egipto", "Congo", "Sudáfrica",
	"Aral", "Tartaria", "Taymir", "Siberia", "Kamchatka", "China", "India", "Japón",
	"Australia", "Java", "Sumatra", "Borneo"
]

const TERRITORY_CODES: Array = [
	"ARG", "BRA", "CHL", "COL", "PER",
	"MEX", "CAL", "NYK", "CAN",
	"GBR", "ESP", "FRA", "ALE", "RUS",
	"SAH", "EGP", "CON", "SUD",
	"ARA", "TAR", "TAY", "SIB", "KAM", "CHN", "IND", "JAP",
	"AUS", "JAV", "SUM", "BOR"
]

const CONTINENTS_DATA: Array = [
	{
		"id": 0,
		"name": "América del Sur",
		"bonus": 2,
		"territories": [0, 1, 2, 3, 4],
		"color": Color(0.90, 0.42, 0.42)
	},
	{
		"id": 1,
		"name": "América del Norte",
		"bonus": 3,
		"territories": [5, 6, 7, 8],
		"color": Color(0.38, 0.68, 0.95)
	},
	{
		"id": 2,
		"name": "Europa",
		"bonus": 5,
		"territories": [9, 10, 11, 12, 13],
		"color": Color(0.45, 0.80, 0.48)
	},
	{
		"id": 3,
		"name": "África",
		"bonus": 3,
		"territories": [14, 15, 16, 17],
		"color": Color(0.98, 0.68, 0.28)
	},
	{
		"id": 4,
		"name": "Asia",
		"bonus": 7,
		"territories": [18, 19, 20, 21, 22, 23, 24, 25],
		"color": Color(0.74, 0.44, 0.84)
	},
	{
		"id": 5,
		"name": "Oceanía",
		"bonus": 2,
		"territories": [26, 27, 28, 29],
		"color": Color(0.28, 0.82, 0.88)
	}
]

var TERRITORY_POLYGONS: Array = [
	# --- AMÉRICA DEL SUR (0..4) ---
	# 0: Argentina (Frontera andina compartida con Chile, frontera norte con Perú/Brasil, Río de la Plata, Costa Patagónica y Tierra del Fuego)
	PackedVector2Array([
		Vector2(170, 422), Vector2(184, 424), Vector2(195, 425), Vector2(204, 440), Vector2(215, 455),
		Vector2(236, 454), Vector2(255, 452), Vector2(252, 464), Vector2(242, 474), Vector2(246, 484),
		Vector2(236, 496), Vector2(232, 510), Vector2(222, 522), Vector2(216, 534), Vector2(224, 544),
		Vector2(204, 548), Vector2(186, 542), Vector2(174, 530), Vector2(168, 518), Vector2(166, 498),
		Vector2(170, 478), Vector2(168, 456), Vector2(172, 438)
	]),
	# 1: Brasil (Guayanas, Delta del Amazonas, Cabo de São Roque, Bahía, Costa Atlántica Sur y frontera amazónica)
	PackedVector2Array([
		Vector2(215, 315), Vector2(228, 318), Vector2(242, 326), Vector2(256, 334), Vector2(272, 338),
		Vector2(290, 346), Vector2(304, 358), Vector2(308, 372), Vector2(302, 388), Vector2(296, 404),
		Vector2(286, 418), Vector2(280, 434), Vector2(268, 446), Vector2(255, 452), Vector2(236, 454),
		Vector2(215, 455), Vector2(204, 440), Vector2(195, 425), Vector2(192, 404), Vector2(196, 382),
		Vector2(195, 362), Vector2(212, 361), Vector2(226, 356), Vector2(220, 336)
	]),
	# 2: Chile (Desierto de Atacama, Costa Pacífica central, Fiordos australes, Cabo de Hornos y Cordillera de los Andes)
	PackedVector2Array([
		Vector2(138, 424), Vector2(154, 423), Vector2(170, 422), Vector2(172, 438), Vector2(168, 456),
		Vector2(170, 478), Vector2(166, 498), Vector2(168, 518), Vector2(174, 530), Vector2(186, 542),
		Vector2(168, 544), Vector2(152, 534), Vector2(144, 518), Vector2(140, 498), Vector2(136, 478),
		Vector2(138, 458), Vector2(134, 440)
	]),
	# 3: Colombia (Istmo de Darién, Costa Caribe, Golfo de Maracaibo, Orinoco y Pacífico Norte)
	PackedVector2Array([
		Vector2(152, 308), Vector2(166, 304), Vector2(182, 302), Vector2(198, 308), Vector2(215, 315),
		Vector2(220, 336), Vector2(226, 356), Vector2(212, 361), Vector2(195, 362), Vector2(176, 364),
		Vector2(158, 364), Vector2(140, 365), Vector2(138, 348), Vector2(144, 332), Vector2(146, 318)
	]),
	# 4: Perú (Golfo de Guayaquil, Punta Pariñas, Costa Pacífica peruana, Altiplano y Selva Amazónica)
	PackedVector2Array([
		Vector2(140, 365), Vector2(158, 364), Vector2(176, 364), Vector2(195, 362), Vector2(196, 382),
		Vector2(192, 404), Vector2(195, 425), Vector2(184, 424), Vector2(170, 422), Vector2(154, 423),
		Vector2(138, 424), Vector2(130, 410), Vector2(122, 394), Vector2(124, 380), Vector2(132, 372)
	]),

	# --- AMÉRICA DEL NORTE (5..8) ---
	# 5: México (Baja California, Pacífico Mexicano, Istmo de Tehuantepec, Centroamérica, Yucatán y Golfo de México)
	PackedVector2Array([
		Vector2(88, 214), Vector2(114, 216), Vector2(138, 214), Vector2(160, 215), Vector2(156, 228),
		Vector2(158, 242), Vector2(168, 248), Vector2(182, 242), Vector2(188, 252), Vector2(180, 266),
		Vector2(188, 276), Vector2(182, 290), Vector2(166, 304), Vector2(152, 308), Vector2(144, 296),
		Vector2(130, 286), Vector2(116, 274), Vector2(104, 258), Vector2(96, 244), Vector2(86, 232)
	]),
	# 6: California (Costa Oeste de EE.UU., Puget Sound, Cabo Mendocino, Rocosas y Río Bravo)
	PackedVector2Array([
		Vector2(72, 128), Vector2(104, 130), Vector2(136, 130), Vector2(165, 130), Vector2(166, 152),
		Vector2(162, 174), Vector2(164, 196), Vector2(160, 215), Vector2(138, 214), Vector2(114, 216),
		Vector2(88, 214), Vector2(76, 198), Vector2(66, 182), Vector2(62, 164), Vector2(66, 146)
	]),
	# 7: Nueva York (Grandes Lagos, Nueva Escocia, Cabo Cod, Bahía de Chesapeake, Península de Florida y Costa del Golfo)
	PackedVector2Array([
		Vector2(165, 130), Vector2(188, 126), Vector2(212, 122), Vector2(234, 118), Vector2(252, 114),
		Vector2(266, 124), Vector2(272, 138), Vector2(260, 150), Vector2(264, 162), Vector2(252, 176),
		Vector2(242, 190), Vector2(236, 204), Vector2(232, 222), Vector2(222, 224), Vector2(216, 208),
		Vector2(202, 206), Vector2(184, 208), Vector2(160, 215), Vector2(164, 196), Vector2(162, 174),
		Vector2(166, 152)
	]),
	# 8: Canadá (Península de Alaska, Islas Aleutianas, Ártico Canadiense, Bahía de Hudson, Labrador y Terranova)
	PackedVector2Array([
		Vector2(34, 82), Vector2(44, 64), Vector2(64, 52), Vector2(92, 48), Vector2(120, 44),
		Vector2(148, 48), Vector2(166, 62), Vector2(178, 76), Vector2(194, 72), Vector2(206, 56),
		Vector2(226, 52), Vector2(246, 64), Vector2(258, 82), Vector2(264, 98), Vector2(252, 114),
		Vector2(234, 118), Vector2(212, 122), Vector2(188, 126), Vector2(165, 130), Vector2(136, 130),
		Vector2(104, 130), Vector2(72, 128), Vector2(56, 116), Vector2(42, 108), Vector2(26, 98)
	]),

	# --- EUROPA (9..13) ---
	# 9: Gran Bretaña (Escocia, Mar de Irlanda, Gales, Cornualles y Canal de la Mancha)
	PackedVector2Array([
		Vector2(326, 72), Vector2(344, 66), Vector2(362, 70), Vector2(372, 82), Vector2(368, 96),
		Vector2(378, 108), Vector2(374, 122), Vector2(356, 126), Vector2(336, 128), Vector2(318, 124),
		Vector2(314, 110), Vector2(322, 98), Vector2(316, 84)
	]),
	# 10: España (Galicia, Portugal, Estrecho de Gibraltar, Costa Mediterránea y Pirineos)
	PackedVector2Array([
		Vector2(306, 174), Vector2(326, 172), Vector2(348, 174), Vector2(372, 178), Vector2(368, 194),
		Vector2(362, 210), Vector2(354, 226), Vector2(338, 238), Vector2(320, 240), Vector2(306, 232),
		Vector2(300, 216), Vector2(298, 198), Vector2(300, 184)
	]),
	# 11: Francia (Península de Bretaña, Normandía, Golfo de Vizcaya, Pirineos, Provenza, Alpes y Rin)
	PackedVector2Array([
		Vector2(372, 140), Vector2(392, 136), Vector2(414, 138), Vector2(432, 140), Vector2(430, 160),
		Vector2(434, 178), Vector2(432, 198), Vector2(418, 210), Vector2(400, 214), Vector2(384, 208),
		Vector2(372, 178), Vector2(348, 174), Vector2(356, 162), Vector2(346, 152), Vector2(358, 144)
	]),
	# 12: Alemania (Península de Jutlandia, Costa Báltica, Europa Central, Alpes e Italia Norte)
	PackedVector2Array([
		Vector2(432, 140), Vector2(436, 122), Vector2(444, 106), Vector2(458, 104), Vector2(464, 116),
		Vector2(478, 114), Vector2(492, 112), Vector2(494, 136), Vector2(490, 160), Vector2(492, 182),
		Vector2(480, 196), Vector2(468, 210), Vector2(456, 204), Vector2(444, 198), Vector2(432, 198),
		Vector2(434, 178), Vector2(430, 160)
	]),
	# 13: Rusia (Península Escandinava, Península de Kola, Báltico, Europa Oriental, Mar Negro y Montes Urales)
	PackedVector2Array([
		Vector2(478, 66), Vector2(496, 54), Vector2(520, 52), Vector2(546, 58), Vector2(564, 68),
		Vector2(572, 82), Vector2(572, 95), Vector2(570, 122), Vector2(574, 150), Vector2(572, 178),
		Vector2(552, 180), Vector2(530, 178), Vector2(516, 184), Vector2(502, 184), Vector2(492, 182),
		Vector2(490, 160), Vector2(494, 136), Vector2(492, 112), Vector2(484, 96), Vector2(474, 82)
	]),

	# --- ÁFRICA (14..17) ---
	# 14: Sahara (Marruecos, Atlas, Cabo Verde, Costa de Marfil, Golfo de Guinea y Desierto del Sahara)
	PackedVector2Array([
		Vector2(342, 262), Vector2(366, 258), Vector2(392, 262), Vector2(412, 266), Vector2(428, 265),
		Vector2(426, 294), Vector2(430, 324), Vector2(428, 355), Vector2(404, 360), Vector2(382, 364),
		Vector2(362, 360), Vector2(342, 348), Vector2(326, 332), Vector2(318, 312), Vector2(322, 292),
		Vector2(330, 276)
	]),
	# 15: Egipto (Delta del Nilo, Canal de Suez, Mar Rojo, Cuerno de África / Somalia y Valle del Rift)
	PackedVector2Array([
		Vector2(428, 265), Vector2(452, 262), Vector2(476, 264), Vector2(492, 272), Vector2(504, 290),
		Vector2(516, 304), Vector2(532, 312), Vector2(526, 328), Vector2(512, 344), Vector2(496, 356),
		Vector2(485, 355), Vector2(456, 354), Vector2(428, 355), Vector2(430, 324), Vector2(426, 294)
	]),
	# 16: Congo (Cuenca del Congo, Costa de Gabón y Angola, Grandes Lagos Africanos y Tanzania)
	PackedVector2Array([
		Vector2(382, 364), Vector2(404, 360), Vector2(428, 355), Vector2(456, 354), Vector2(485, 355),
		Vector2(496, 356), Vector2(492, 376), Vector2(486, 398), Vector2(482, 418), Vector2(478, 438),
		Vector2(448, 440), Vector2(418, 438), Vector2(388, 438), Vector2(386, 416), Vector2(382, 396),
		Vector2(378, 378)
	]),
	# 17: Sudáfrica (Costa de Namibia, Cabo de Buena Esperanza, Cabo Agujas, Natal y Canal de Mozambique)
	PackedVector2Array([
		Vector2(388, 438), Vector2(418, 438), Vector2(448, 440), Vector2(478, 438), Vector2(482, 456),
		Vector2(474, 476), Vector2(468, 496), Vector2(458, 514), Vector2(442, 528), Vector2(422, 530),
		Vector2(406, 520), Vector2(398, 500), Vector2(394, 478), Vector2(390, 458)
	]),

	# --- ASIA (18..25) ---
	# 18: Aral (Cáucaso, Mar Caspio, Meseta Iraní, Estepa Kazaja y Pamir)
	PackedVector2Array([
		Vector2(530, 178), Vector2(552, 180), Vector2(572, 178), Vector2(598, 180), Vector2(620, 178),
		Vector2(640, 178), Vector2(642, 200), Vector2(638, 222), Vector2(640, 245), Vector2(612, 244),
		Vector2(584, 246), Vector2(556, 245), Vector2(540, 240), Vector2(528, 226), Vector2(524, 208),
		Vector2(526, 192)
	]),
	# 19: Tartaria (Montes Urales, Golfo del Obi, Llanura de Siberia Occidental y Río Yeniséi)
	PackedVector2Array([
		Vector2(572, 95), Vector2(588, 86), Vector2(606, 88), Vector2(625, 95), Vector2(625, 108),
		Vector2(650, 110), Vector2(675, 108), Vector2(673, 132), Vector2(677, 156), Vector2(675, 178),
		Vector2(640, 178), Vector2(620, 178), Vector2(598, 180), Vector2(572, 178), Vector2(574, 150),
		Vector2(570, 122)
	]),
	# 20: Taymir (Península de Taymir, Cabo Cheliuskin, Costa Ártica y Delta del Lena)
	PackedVector2Array([
		Vector2(625, 95), Vector2(628, 74), Vector2(642, 56), Vector2(664, 44), Vector2(688, 42),
		Vector2(712, 48), Vector2(732, 58), Vector2(742, 74), Vector2(738, 92), Vector2(735, 108),
		Vector2(704, 106), Vector2(675, 108), Vector2(650, 110), Vector2(625, 108)
	]),
	# 21: Siberia (Meseta Central Siberiana, Lago Baikal, Yakutia y Montes Stanovói)
	PackedVector2Array([
		Vector2(675, 108), Vector2(704, 106), Vector2(735, 108), Vector2(756, 106), Vector2(775, 108),
		Vector2(778, 132), Vector2(772, 156), Vector2(775, 182), Vector2(744, 184), Vector2(710, 180),
		Vector2(675, 178), Vector2(677, 156), Vector2(673, 132)
	]),
	# 22: Kamchatka (Chukotka, Estrecho de Bering, Península de Kamchatka, Mar de Ojotsk y Sajalín)
	PackedVector2Array([
		Vector2(775, 108), Vector2(782, 86), Vector2(798, 70), Vector2(822, 64), Vector2(848, 66),
		Vector2(872, 74), Vector2(888, 90), Vector2(884, 108), Vector2(868, 120), Vector2(862, 138),
		Vector2(852, 158), Vector2(840, 168), Vector2(832, 152), Vector2(824, 136), Vector2(806, 146),
		Vector2(792, 164), Vector2(775, 168), Vector2(772, 156), Vector2(778, 132)
	]),
	# 23: China (Mongolia, Manchuria, Península de Corea, Mar Amarillo, Costa Sur de China e Indochina)
	PackedVector2Array([
		Vector2(640, 178), Vector2(675, 178), Vector2(710, 180), Vector2(744, 184), Vector2(775, 182),
		Vector2(788, 192), Vector2(792, 208), Vector2(780, 216), Vector2(786, 232), Vector2(778, 248),
		Vector2(762, 262), Vector2(742, 270), Vector2(726, 282), Vector2(712, 290), Vector2(698, 278),
		Vector2(682, 270), Vector2(660, 268), Vector2(640, 268), Vector2(640, 245), Vector2(638, 222),
		Vector2(642, 200)
	]),
	# 24: India (Himalaya, Mar Arábigo, Decán, Cabo Comorín, Golfo de Bengala y Birmania)
	PackedVector2Array([
		Vector2(556, 245), Vector2(584, 246), Vector2(612, 244), Vector2(640, 245), Vector2(640, 268),
		Vector2(644, 286), Vector2(632, 298), Vector2(618, 314), Vector2(606, 334), Vector2(594, 346),
		Vector2(582, 332), Vector2(570, 312), Vector2(558, 294), Vector2(548, 276), Vector2(546, 258)
	]),
	# 25: Japón (Hokkaido, Arco de Honshu, Shikoku y Kyushu)
	PackedVector2Array([
		Vector2(826, 184), Vector2(848, 182), Vector2(868, 190), Vector2(876, 206), Vector2(872, 224),
		Vector2(862, 242), Vector2(846, 256), Vector2(826, 262), Vector2(808, 256), Vector2(804, 240),
		Vector2(814, 224), Vector2(822, 206)
	]),

	# --- OCEANÍA (26..29) ---
	# 26: Australia (Kimberley, Tierra de Arnhem, Golfo de Carpentaria, Cabo York, Gran Barrera y Gran Bahía Australiana)
	PackedVector2Array([
		Vector2(696, 474), Vector2(716, 462), Vector2(738, 456), Vector2(756, 464), Vector2(772, 474),
		Vector2(786, 458), Vector2(798, 450), Vector2(812, 464), Vector2(830, 476), Vector2(848, 492),
		Vector2(856, 510), Vector2(848, 528), Vector2(830, 540), Vector2(806, 544), Vector2(784, 536),
		Vector2(760, 530), Vector2(734, 534), Vector2(710, 538), Vector2(692, 528), Vector2(686, 510),
		Vector2(688, 490)
	]),
	# 27: Java (Arco de Java, Bali, Célebes y Nueva Guinea Occidental)
	PackedVector2Array([
		Vector2(692, 396), Vector2(714, 390), Vector2(738, 388), Vector2(764, 392), Vector2(786, 398),
		Vector2(794, 412), Vector2(788, 428), Vector2(772, 438), Vector2(746, 442), Vector2(718, 440),
		Vector2(696, 434), Vector2(686, 420), Vector2(686, 406)
	]),
	# 28: Sumatra (Aceh, Estrecho de Malaca, Costa del Océano Índico y Estrecho de la Sonda)
	PackedVector2Array([
		Vector2(628, 326), Vector2(648, 320), Vector2(672, 322), Vector2(696, 328), Vector2(712, 340),
		Vector2(714, 356), Vector2(704, 372), Vector2(684, 378), Vector2(658, 378), Vector2(636, 372),
		Vector2(624, 358), Vector2(622, 342)
	]),
	# 29: Borneo (Sabah, Sarawak, Kalimantan y Estrecho de Macasar)
	PackedVector2Array([
		Vector2(744, 304), Vector2(768, 298), Vector2(794, 302), Vector2(814, 312), Vector2(822, 328),
		Vector2(818, 346), Vector2(804, 360), Vector2(780, 364), Vector2(754, 362), Vector2(736, 354),
		Vector2(730, 338), Vector2(734, 320)
	])
]

const TERRITORY_CENTERS: Array = [
	Vector2(208, 488), # 0: Argentina
	Vector2(248, 396), # 1: Brasil
	Vector2(150, 478), # 2: Chile
	Vector2(180, 336), # 3: Colombia
	Vector2(160, 395), # 4: Perú

	Vector2(142, 256), # 5: México
	Vector2(118, 172), # 6: California
	Vector2(210, 168), # 7: Nueva York
	Vector2(150, 92),  # 8: Canadá

	Vector2(348, 100), # 9: Gran Bretaña
	Vector2(336, 206), # 10: España
	Vector2(402, 176), # 11: Francia
	Vector2(462, 156), # 12: Alemania
	Vector2(532, 124), # 13: Rusia

	Vector2(380, 316), # 14: Sahara
	Vector2(468, 310), # 15: Egipto
	Vector2(434, 398), # 16: Congo
	Vector2(434, 482), # 17: Sudáfrica

	Vector2(585, 212), # 18: Aral
	Vector2(622, 142), # 19: Tartaria
	Vector2(682, 78),  # 20: Taymir
	Vector2(725, 145), # 21: Siberia
	Vector2(828, 116), # 22: Kamchatka
	Vector2(710, 228), # 23: China
	Vector2(594, 288), # 24: India
	Vector2(842, 224), # 25: Japón

	Vector2(772, 502), # 26: Australia
	Vector2(740, 416), # 27: Java
	Vector2(668, 350), # 28: Sumatra
	Vector2(776, 332)  # 29: Borneo
]

const ADJACENCIES: Array = [
	[0, 1], [0, 2], [0, 4],
	[1, 2], [1, 3], [1, 4], [1, 14],
	[2, 4], [2, 26],
	[3, 4], [3, 5],
	[5, 6],
	[6, 7], [6, 8],
	[7, 8], [7, 10],
	[8, 22],
	[9, 10], [9, 11], [9, 12],
	[10, 11], [10, 14],
	[11, 12],
	[12, 13],
	[13, 18], [13, 19],
	[14, 15], [14, 16],
	[15, 16], [15, 17], [15, 18],
	[16, 17],
	[18, 19], [18, 24],
	[19, 20], [19, 21], [19, 23],
	[20, 21],
	[21, 22], [21, 23],
	[22, 25],
	[23, 24], [23, 25], [23, 28],
	[24, 28],
	[26, 27],
	[27, 29],
	[28, 29]
]

const SEA_LANES: Array = [
	[1, 14],   # Brasil <-> Sahara
	[2, 26],   # Chile <-> Australia
	[3, 5],    # Colombia <-> México
	[7, 10],   # Nueva York <-> España
	[8, 22],   # Canadá <-> Kamchatka
	[10, 14],  # España <-> Sahara
	[15, 18],  # Egipto <-> Aral
	[22, 25],  # Kamchatka <-> Japón
	[23, 28],  # China <-> Sumatra
	[24, 28],  # India <-> Sumatra
	[26, 27],  # Australia <-> Java
	[27, 29],  # Java <-> Borneo
	[28, 29],  # Sumatra <-> Borneo
	[9, 10],   # Gran Bretaña <-> España
	[9, 11],   # Gran Bretaña <-> Francia
	[9, 12]    # Gran Bretaña <-> Alemania
]

const PLAYER_COLORS: Dictionary = {
	1: Color(0.92, 0.25, 0.25), # P1: Rojo Imperial
	2: Color(0.22, 0.52, 0.95), # P2: Azul Cobalto
	3: Color(0.18, 0.82, 0.38), # P3: Verde Esmeralda
	4: Color(0.96, 0.80, 0.15), # P4: Amarillo Oro
	5: Color(0.74, 0.30, 0.92), # P5: Púrpura Real
	6: Color(0.96, 0.52, 0.18)  # P6: Naranja Fuego
}

const PLAYER_NAMES: Dictionary = {
	1: "Rojo (1)",
	2: "Azul (2)",
	3: "Verde (3)",
	4: "Amarillo (4)",
	5: "Púrpura (5)",
	6: "Naranja (6)"
}

const CARD_TYPES: Dictionary = {
	0: { "name": "Infantería", "icon": "🪖" },
	1: { "name": "Caballería", "icon": "🐎" },
	2: { "name": "Artillería", "icon": "💥" },
	3: { "name": "Comodín", "icon": "⭐" }
}

var bridge
var current_player_id: int = 1
var current_phase: String = "PlaceArmies"
var armies_remaining_to_place: int = 0
var winner: int = -1

var territory_owners: Dictionary = {}
var territory_armies: Dictionary = {}
var territory_labels: Dictionary = {} # For backward-compatibility

var selected_from: int = -1
var selected_to: int = -1
var hovered_territory: int = -1
var valid_targets: Array[int] = []

# Cards and Objectives state
var player_cards: Dictionary = { 1: [], 2: [], 3: [], 4: [], 5: [], 6: [] }
var selected_card_indices: Array[int] = []
var exchange_count: int = 0
var player_objectives: Dictionary = {}

var is_vs_ai: bool = false
var human_player_id: int = 1
var ai_player_id: int = 2
var _is_human_attacking: bool = false
var current_layout: int = 0
var sidebar_collapsed: bool = false

# UI Nodes
var status_label: Label = null
var map_panel: Panel
var map_canvas: Control
var top_bar_panel: Panel
var sidebar_panel: Panel
var tab_container: TabContainer
var btn_toggle_panel: Button
var title_label_node: Label
var btn_rules_node: Button

var objective_card_panel: PanelContainer
var objective_title_label: Label
var objective_desc_label: Label
var objective_progress_bar: ProgressBar
var objective_progress_label: Label

var cards_container: HBoxContainer
var cards_info_label: Label
var btn_exchange: Button

var action_title_label: Label
var action_info_label: Label
var btn_place: Button
var btn_place_5: Button
var btn_place_all: Button
var btn_attack: Button
var btn_fortify: Button
var btn_end_phase: Button
var attack_dice_spinbox: SpinBox
var fortify_armies_spinbox: SpinBox

var player_stats_label: Label
var turn_indicator: TurnIndicator
var current_theme: BoardTheme
var rules_popup: RulesPopup
var dice_popup: PopupPanel
var dice_label: Label
var dice_widget: DiceWidget
var _pause_menu: CanvasLayer
var mode_option_button: OptionButton

# Pulse animation timer
var pulse_time: float = 0.0

func _ready() -> void:
	if has_node("Status"):
		status_label = get_node_or_null("Status")
		if status_label != null:
			status_label.visible = false

	if Engine.has_singleton("ThemeManager") or (is_inside_tree() and has_node("/root/ThemeManager")):
		var tm: Node = null
		if is_inside_tree():
			tm = get_node_or_null("/root/ThemeManager")
		if tm != null:
			current_theme = tm.get_theme()
			tm.theme_changed.connect(_on_theme_changed)
	else:
		_create_default_theme()

	_setup_default_objectives()
	_setup_default_cards()
	_setup_ui()

	var gm: Node = null
	if is_inside_tree():
		gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("layout_changed"):
		gm.layout_changed.connect(_on_layout_changed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	bridge = OpenTableBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)

	# HUD de red — solo en modo Host/Client, nunca en headless
	if not OS.has_feature("headless"):
		if bridge.has_method("is_network_mode") and bridge.call("is_network_mode"):
			var hud_script = load("res://network_status_hud.gd")
			if hud_script:
				var hud: Node = hud_script.new()
				if hud.has_method("setup"):
					hud.setup(bridge)
				elif hud.has_method("bind_bridge"):
					hud.bind_bridge(bridge)
				add_child(hud)

	bridge.connect("game_over", _on_game_over)
	bridge.connect("move_rejected", _on_move_rejected)
	bridge.connect("event_json", _on_event_json)

	if bridge.has_signal("territory_conquered"):
		bridge.connect("territory_conquered", _on_territory_conquered)
	if bridge.has_signal("attack_resolved"):
		bridge.connect("attack_resolved", _on_attack_resolved)
	if bridge.has_signal("armies_placed"):
		bridge.connect("armies_placed", _on_armies_placed)
	if bridge.has_signal("player_eliminated"):
		bridge.connect("player_eliminated", _on_player_eliminated)
	if bridge.has_signal("phase_changed"):
		bridge.connect("phase_changed", _on_phase_changed)
	if bridge.has_signal("cards_exchanged"):
		bridge.connect("cards_exchanged", _on_cards_exchanged)
	if bridge.has_signal("crisis_game_over"):
		bridge.connect("crisis_game_over", _on_crisis_game_over)
	if bridge.has_signal("turn_changed"):
		bridge.connect("turn_changed", _on_turn_changed)

	is_vs_ai = (gm != null and gm.has_method("get_game_mode") and str(gm.get_game_mode()) == "vs_ai")
	if is_vs_ai:
		human_player_id = int(gm.get_human_player_id()) if (gm != null and gm.has_method("get_human_player_id")) else 1
		ai_player_id = 2 if human_player_id == 1 else 1
		var diff: int = int(gm.get_ai_difficulty()) if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		bridge.start_local_match_crisis_vs_ai(human_player_id, ai_player_id, diff)
		if mode_option_button != null:
			mode_option_button.selected = 1 if human_player_id == 1 else 2
	else:
		human_player_id = 1
		ai_player_id = 2
		bridge.start_local_match_crisis(42, [1, 2])
		if mode_option_button != null:
			mode_option_button.selected = 0
	current_player_id = bridge.current_player()

	_sync_all_from_bridge()
	var initial_layout: int = int(gm.get_layout()) if (gm != null and gm.has_method("get_layout")) else 0
	_on_layout_changed(initial_layout)
	_update_ui_state()

	if not OS.has_feature("headless"):
		_pause_menu = load("res://pause_menu.tscn").instantiate()
		_pause_menu.connect("quit_game_requested", _on_quit_to_menu)
		add_child(_pause_menu)

func _on_quit_to_menu() -> void:
	if (is_inside_tree() and has_node("/root/SceneManager")):
		get_node("/root/SceneManager").transition_to("res://main.tscn")
	else:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://main.tscn")

func _on_mode_selected(index: int) -> void:
	var gm: Node = null
	if is_inside_tree():
		gm = get_node_or_null("/root/GameManager")
	winner = -1
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	if index == 0:
		is_vs_ai = false
		human_player_id = 1
		ai_player_id = 2
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("local")
		bridge.start_local_match_crisis(42, [1, 2])
	else:
		is_vs_ai = true
		human_player_id = 1 if index == 1 else 2
		ai_player_id = 2 if human_player_id == 1 else 1
		var diff: int = int(gm.get_ai_difficulty()) if (gm != null and gm.has_method("get_ai_difficulty")) else 1
		if gm != null and gm.has_method("set_game_mode"):
			gm.set_game_mode("vs_ai")
		if gm != null and gm.has_method("set_human_player_id"):
			gm.set_human_player_id(human_player_id)
		bridge.start_local_match_crisis_vs_ai(human_player_id, ai_player_id, diff)
	current_player_id = bridge.current_player()
	_sync_all_from_bridge()
	_update_ui_state()

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	if selected_from != -1 or valid_targets.size() > 0:
		if map_canvas:
			map_canvas.queue_redraw()

func _create_default_theme() -> void:
	current_theme = BoardTheme.new()
	current_theme.theme_name = "Noche Azul"
	current_theme.board_color = Color("#121A24")
	current_theme.line_color = Color("#7C9BB8")
	current_theme.light_color = Color("#5B7A9C")
	current_theme.dark_color = Color("#1A2634")
	current_theme.select_color = Color(1.0, 0.85, 0.25, 0.85)
	current_theme.valid_move_color = Color(0.2, 0.9, 0.5, 0.85)

func _setup_default_objectives() -> void:
	player_objectives[1] = {
		"title": "Conquistar 24 Territorios",
		"desc": "Ocupar 24 territorios cualesquiera en el planeta con al menos 1 ejército.",
		"target_type": "territories",
		"target_count": 24
	}
	player_objectives[2] = {
		"title": "Conquistar América del Sur y Europa",
		"desc": "Ocupar la totalidad de América del Sur (5 territorios) y Europa (5 territorios).",
		"target_type": "continents",
		"continents": [0, 2]
	}
	for p in range(3, 7):
		player_objectives[p] = {
			"title": "Ocupar 18 Territorios",
			"desc": "Ocupar 18 territorios con al menos 2 ejércitos cada uno.",
			"target_type": "territories",
			"target_count": 18
		}

func _setup_default_cards() -> void:
	# Initial cards for players so exchange mechanics can be tested & visualized immediately
	player_cards[1] = [
		{ "territory": 0, "card_type": 0 }, # Argentina - Infantería
		{ "territory": 1, "card_type": 1 }, # Brasil - Caballería
		{ "territory": 2, "card_type": 2 }, # Chile - Artillería
		{ "territory": 10, "card_type": 3 } # España - Comodín
	]
	player_cards[2] = [
		{ "territory": 5, "card_type": 0 },
		{ "territory": 6, "card_type": 0 },
		{ "territory": 7, "card_type": 0 }
	]

func _on_theme_changed(theme: BoardTheme) -> void:
	current_theme = theme
	_apply_theme_styling()
	if map_canvas:
		map_canvas.queue_redraw()

func _apply_theme_styling() -> void:
	if current_theme == null:
		return

	if map_panel:
		var map_style = StyleBoxFlat.new()
		map_style.bg_color = current_theme.board_color.darkened(0.22)
		map_style.border_color = current_theme.line_color.darkened(0.25)
		map_style.set_border_width_all(0)
		map_panel.add_theme_stylebox_override("panel", map_style)

	if top_bar_panel:
		var top_style = StyleBoxFlat.new()
		var base_dark = current_theme.dark_color.darkened(0.18)
		top_style.bg_color = Color(base_dark.r, base_dark.g, base_dark.b, 0.90)
		top_style.border_color = Color(current_theme.line_color.r, current_theme.line_color.g, current_theme.line_color.b, 0.45)
		top_style.set_border_width_all(1)
		top_style.set_corner_radius_all(10)
		top_bar_panel.add_theme_stylebox_override("panel", top_style)

	if sidebar_panel:
		var side_style = StyleBoxFlat.new()
		var base_side = current_theme.dark_color.darkened(0.15)
		side_style.bg_color = Color(base_side.r, base_side.g, base_side.b, 0.92)
		side_style.border_color = Color(current_theme.line_color.r, current_theme.line_color.g, current_theme.line_color.b, 0.50)
		side_style.set_border_width_all(1)
		side_style.set_corner_radius_all(12)
		sidebar_panel.add_theme_stylebox_override("panel", side_style)

func _setup_ui() -> void:
	# 1. Fullscreen Map Panel (1280x720)
	map_panel = Panel.new()
	map_panel.name = "MapPanel"
	map_panel.position = Vector2(0, 0)
	map_panel.custom_minimum_size = Vector2(1280, 720)
	map_panel.size = Vector2(1280, 720)
	add_child(map_panel)

	# Interactive Canvas for rendering polygons, connection lines, badges, and highlights
	# Use explicit position + size instead of PRESET_FULL_RECT so setting map_canvas.size never triggers anchor warnings
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.position = Vector2.ZERO
	map_canvas.size = Vector2(1280, 720)
	map_canvas.draw.connect(_on_map_canvas_draw)
	map_canvas.gui_input.connect(_on_map_canvas_gui_input)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.add_child(map_canvas)

	# Hidden labels container for backward compatibility with older tests that check territory_labels[i]
	for i in range(30):
		var lbl = Label.new()
		lbl.name = "Territory_" + str(i)
		lbl.visible = false
		add_child(lbl)
		territory_labels[i] = lbl

	# 2. Superimposed Top HUD Bar
	top_bar_panel = Panel.new()
	top_bar_panel.name = "TopBarPanel"
	top_bar_panel.position = Vector2(16, 12)
	top_bar_panel.custom_minimum_size = Vector2(1248, 52)
	top_bar_panel.size = Vector2(1248, 52)
	add_child(top_bar_panel)

	var header_hbox = HBoxContainer.new()
	header_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_hbox.offset_left = 12
	header_hbox.offset_top = 6
	header_hbox.offset_right = -12
	header_hbox.offset_bottom = -6
	header_hbox.add_theme_constant_override("separation", 10)
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar_panel.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "🌍 CRISIS — TEG"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	title_label_node = title_lbl
	header_hbox.add_child(title_lbl)

	turn_indicator = TurnIndicator.new()
	turn_indicator.name = "TurnIndicator"
	turn_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(turn_indicator)

	var mode_opt := OptionButton.new()
	mode_opt.name = "ModeOptionButton"
	mode_option_button = mode_opt
	mode_opt.custom_minimum_size = Vector2(128, 32)
	mode_opt.add_item("👥 Hotseat", 0)
	mode_opt.add_item("🤖 vs IA (J1)", 1)
	mode_opt.add_item("🤖 vs IA (J2)", 2)
	var gm_ref: Node = null
	if is_inside_tree():
		gm_ref = get_node_or_null("/root/GameManager")
	if gm_ref != null and gm_ref.has_method("get_game_mode") and str(gm_ref.get_game_mode()) == "vs_ai":
		var hp: int = int(gm_ref.get_human_player_id()) if gm_ref.has_method("get_human_player_id") else 1
		mode_opt.selected = 1 if hp == 1 else 2
	else:
		mode_opt.selected = 0
	mode_opt.visible = false
	mode_opt.item_selected.connect(_on_mode_selected)
	header_hbox.add_child(mode_opt)

	var btn_rules = Button.new()
	btn_rules.name = "RulesButton"
	btn_rules.text = "📖 Reglas"
	btn_rules.custom_minimum_size = Vector2(86, 32)
	btn_rules.visible = false
	btn_rules.pressed.connect(func(): rules_popup.show_for_game("crisis"))
	btn_rules_node = btn_rules
	header_hbox.add_child(btn_rules)

	var top_menu_spacer: Control = Control.new()
	top_menu_spacer.name = "TopMenuSpacer"
	top_menu_spacer.custom_minimum_size = Vector2(126, 32)
	header_hbox.add_child(top_menu_spacer)

	# 3. Superimposed Floating Tactical Control Panel (Right Side on Desktop, Collapsible Bottom Drawer on Mobile)
	sidebar_panel = Panel.new()
	sidebar_panel.name = "SidebarPanel"
	sidebar_panel.clip_contents = true
	sidebar_panel.position = Vector2(912, 74)
	sidebar_panel.custom_minimum_size = Vector2(352, 632)
	sidebar_panel.size = Vector2(352, 632)
	add_child(sidebar_panel)

	var sidebar_vbox = VBoxContainer.new()
	sidebar_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	sidebar_vbox.add_theme_constant_override("separation", 8)
	sidebar_vbox.offset_left = 12
	sidebar_vbox.offset_top = 8
	sidebar_vbox.offset_right = -12
	sidebar_vbox.offset_bottom = -10
	sidebar_panel.add_child(sidebar_vbox)

	# Top row of Sidebar: Player Statistics + Small Sleek Corner Icon Button
	var sidebar_header_hbox = HBoxContainer.new()
	sidebar_header_hbox.add_theme_constant_override("separation", 6)
	sidebar_header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sidebar_vbox.add_child(sidebar_header_hbox)

	player_stats_label = Label.new()
	player_stats_label.text = "Turno: Rojo (1)"
	player_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_stats_label.add_theme_font_size_override("font_size", 11)
	sidebar_header_hbox.add_child(player_stats_label)

	btn_toggle_panel = Button.new()
	btn_toggle_panel.name = "TogglePanelButton"
	btn_toggle_panel.text = "▾"
	btn_toggle_panel.tooltip_text = "Plegar / desplegar panel táctico"
	btn_toggle_panel.custom_minimum_size = Vector2(24, 24)
	btn_toggle_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn_toggle_panel.add_theme_font_size_override("font_size", 12)
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.14, 0.20, 0.28, 0.85)
	toggle_style.border_color = Color(0.65, 0.78, 0.92, 0.45)
	toggle_style.set_border_width_all(1)
	toggle_style.set_corner_radius_all(6)
	toggle_style.content_margin_left = 4
	toggle_style.content_margin_right = 4
	toggle_style.content_margin_top = 1
	toggle_style.content_margin_bottom = 1
	btn_toggle_panel.add_theme_stylebox_override("normal", toggle_style)
	var toggle_hover := toggle_style.duplicate()
	toggle_hover.bg_color = Color(0.22, 0.32, 0.44, 0.95)
	btn_toggle_panel.add_theme_stylebox_override("hover", toggle_hover)
	btn_toggle_panel.pressed.connect(_on_toggle_sidebar_pressed)
	sidebar_header_hbox.add_child(btn_toggle_panel)

	# Tab Container for Actions, Objectives, Cards, and Continents Summary
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_size_override("font_size", 12)
	sidebar_vbox.add_child(tab_container)

	# --- Tab 1: Acciones de Turno ---
	var actions_tab = VBoxContainer.new()
	actions_tab.name = "Acciones"
	actions_tab.add_theme_constant_override("separation", 7)
	tab_container.add_child(actions_tab)
	tab_container.set_tab_title(0, "Acción")

	action_title_label = Label.new()
	action_title_label.text = "Fase: Colocación de Tropas"
	action_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_title_label.add_theme_font_size_override("font_size", 13)
	action_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	actions_tab.add_child(action_title_label)

	action_info_label = Label.new()
	action_info_label.text = "Toca uno de tus territorios en el mapa para colocar ejércitos."
	action_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_info_label.add_theme_font_size_override("font_size", 12)
	actions_tab.add_child(action_info_label)

	var place_hbox = HBoxContainer.new()
	place_hbox.add_theme_constant_override("separation", 6)
	place_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_tab.add_child(place_hbox)

	btn_place = Button.new()
	btn_place.text = "+1 Tropa"
	btn_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_place.custom_minimum_size = Vector2(0, 34)
	btn_place.add_theme_font_size_override("font_size", 12)
	btn_place.pressed.connect(_on_btn_place_pressed)
	place_hbox.add_child(btn_place)

	btn_place_5 = Button.new()
	btn_place_5.text = "+5 Tropas"
	btn_place_5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_place_5.custom_minimum_size = Vector2(0, 34)
	btn_place_5.add_theme_font_size_override("font_size", 12)
	btn_place_5.pressed.connect(func(): _place_armies(5))
	place_hbox.add_child(btn_place_5)

	btn_place_all = Button.new()
	btn_place_all.text = "Todas"
	btn_place_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_place_all.custom_minimum_size = Vector2(0, 34)
	btn_place_all.add_theme_font_size_override("font_size", 12)
	btn_place_all.pressed.connect(func(): _place_armies(armies_remaining_to_place))
	place_hbox.add_child(btn_place_all)

	var attack_hbox = HBoxContainer.new()
	attack_hbox.add_theme_constant_override("separation", 6)
	attack_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_tab.add_child(attack_hbox)

	var dice_lbl = Label.new()
	dice_lbl.text = "Dados:"
	dice_lbl.add_theme_font_size_override("font_size", 12)
	attack_hbox.add_child(dice_lbl)

	attack_dice_spinbox = SpinBox.new()
	attack_dice_spinbox.min_value = 1
	attack_dice_spinbox.max_value = 3
	attack_dice_spinbox.value = 3
	attack_dice_spinbox.custom_minimum_size = Vector2(68, 32)
	attack_hbox.add_child(attack_dice_spinbox)

	btn_attack = Button.new()
	btn_attack.text = "⚔️ Atacar"
	btn_attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_attack.custom_minimum_size = Vector2(0, 34)
	btn_attack.add_theme_font_size_override("font_size", 12)
	btn_attack.pressed.connect(_on_btn_attack_pressed)
	attack_hbox.add_child(btn_attack)

	var fortify_hbox = HBoxContainer.new()
	fortify_hbox.add_theme_constant_override("separation", 6)
	fortify_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_tab.add_child(fortify_hbox)

	var fort_lbl = Label.new()
	fort_lbl.text = "Tropas:"
	fort_lbl.add_theme_font_size_override("font_size", 12)
	fortify_hbox.add_child(fort_lbl)

	fortify_armies_spinbox = SpinBox.new()
	fortify_armies_spinbox.min_value = 1
	fortify_armies_spinbox.max_value = 10
	fortify_armies_spinbox.value = 1
	fortify_armies_spinbox.custom_minimum_size = Vector2(68, 32)
	fortify_hbox.add_child(fortify_armies_spinbox)

	btn_fortify = Button.new()
	btn_fortify.text = "🛡️ Fortificar"
	btn_fortify.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fortify.custom_minimum_size = Vector2(0, 34)
	btn_fortify.add_theme_font_size_override("font_size", 12)
	btn_fortify.pressed.connect(_on_btn_fortify_pressed)
	fortify_hbox.add_child(btn_fortify)

	btn_end_phase = Button.new()
	btn_end_phase.text = "Fin de Fase ➡️"
	btn_end_phase.custom_minimum_size = Vector2(0, 36)
	btn_end_phase.add_theme_font_size_override("font_size", 12)
	btn_end_phase.pressed.connect(_on_btn_end_phase_pressed)
	actions_tab.add_child(btn_end_phase)

	# --- Tab 2: Objetivo Secreto (ObjectiveCard UI) ---
	var obj_tab = VBoxContainer.new()
	obj_tab.name = "Objetivo"
	obj_tab.add_theme_constant_override("separation", 8)
	tab_container.add_child(obj_tab)
	tab_container.set_tab_title(1, "Misión")

	objective_card_panel = PanelContainer.new()
	var obj_style = StyleBoxFlat.new()
	obj_style.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	obj_style.border_color = Color(0.95, 0.8, 0.3)
	obj_style.set_border_width_all(2)
	obj_style.corner_radius_top_left = 8
	obj_style.corner_radius_top_right = 8
	obj_style.corner_radius_bottom_left = 8
	obj_style.corner_radius_bottom_right = 8
	obj_style.content_margin_left = 10
	obj_style.content_margin_right = 10
	obj_style.content_margin_top = 8
	obj_style.content_margin_bottom = 8
	objective_card_panel.add_theme_stylebox_override("panel", obj_style)
	obj_tab.add_child(objective_card_panel)

	var obj_vbox = VBoxContainer.new()
	obj_vbox.add_theme_constant_override("separation", 5)
	objective_card_panel.add_child(obj_vbox)

	var badge_lbl = Label.new()
	badge_lbl.text = "🎯 MISIÓN SECRETA"
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	obj_vbox.add_child(badge_lbl)

	objective_title_label = Label.new()
	objective_title_label.text = "Conquistar 24 Territorios"
	objective_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_title_label.add_theme_font_size_override("font_size", 14)
	obj_vbox.add_child(objective_title_label)

	objective_desc_label = Label.new()
	objective_desc_label.text = "Ocupar 24 territorios cualesquiera en el planeta con al menos 1 ejército."
	objective_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_desc_label.add_theme_font_size_override("font_size", 12)
	objective_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	obj_vbox.add_child(objective_desc_label)

	var prog_title = Label.new()
	prog_title.text = "Progreso de Conquista:"
	prog_title.add_theme_font_size_override("font_size", 12)
	obj_vbox.add_child(prog_title)

	objective_progress_bar = ProgressBar.new()
	objective_progress_bar.custom_minimum_size = Vector2(0, 18)
	objective_progress_bar.max_value = 24
	objective_progress_bar.value = 15
	obj_vbox.add_child(objective_progress_bar)

	objective_progress_label = Label.new()
	objective_progress_label.text = "15 / 24 territorios"
	objective_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_progress_label.add_theme_font_size_override("font_size", 12)
	obj_vbox.add_child(objective_progress_label)

	# --- Tab 3: Tarjetas de Canje (Territory Cards UI) ---
	var cards_tab = VBoxContainer.new()
	cards_tab.name = "Tarjetas"
	cards_tab.add_theme_constant_override("separation", 6)
	tab_container.add_child(cards_tab)
	tab_container.set_tab_title(2, "Cartas")

	cards_info_label = Label.new()
	cards_info_label.text = "Selecciona 3 tarjetas (3 iguales o 1 de cada tipo) para canjear por ejércitos."
	cards_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards_info_label.add_theme_font_size_override("font_size", 11)
	cards_tab.add_child(cards_info_label)

	var scroll_cards = ScrollContainer.new()
	scroll_cards.custom_minimum_size = Vector2(0, 118)
	scroll_cards.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_cards.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_tab.add_child(scroll_cards)

	cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 6)
	scroll_cards.add_child(cards_container)

	btn_exchange = Button.new()
	btn_exchange.text = "🔄 Canjear (+4 Tropas)"
	btn_exchange.custom_minimum_size = Vector2(0, 34)
	btn_exchange.add_theme_font_size_override("font_size", 12)
	btn_exchange.pressed.connect(_on_btn_exchange_pressed)
	cards_tab.add_child(btn_exchange)

	# --- Tab 4: Continentes y Bonificaciones ---
	var cont_tab = VBoxContainer.new()
	cont_tab.name = "Continentes"
	cont_tab.add_theme_constant_override("separation", 5)
	tab_container.add_child(cont_tab)
	tab_container.set_tab_title(3, "Bonos")

	for c in CONTINENTS_DATA:
		var cont_panel = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = c["color"].darkened(0.65)
		cs.border_color = c["color"]
		cs.set_border_width_all(1)
		cs.corner_radius_top_left = 6
		cs.corner_radius_top_right = 6
		cs.corner_radius_bottom_left = 6
		cs.corner_radius_bottom_right = 6
		cs.content_margin_left = 8
		cs.content_margin_right = 8
		cs.content_margin_top = 3
		cs.content_margin_bottom = 3
		cont_panel.add_theme_stylebox_override("panel", cs)
		cont_tab.add_child(cont_panel)

		var chbox = HBoxContainer.new()
		cont_panel.add_child(chbox)

		var clbl = Label.new()
		clbl.text = "%s (%d)" % [c["name"], c["territories"].size()]
		clbl.add_theme_font_size_override("font_size", 11)
		clbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chbox.add_child(clbl)

		var cbonus = Label.new()
		cbonus.text = "+%d Tropas" % c["bonus"]
		cbonus.add_theme_font_size_override("font_size", 11)
		cbonus.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
		chbox.add_child(cbonus)

	# Dice Popup for Combat resolution
	dice_popup = PopupPanel.new()
	dice_popup.title = "Resultado del Combate"
	dice_popup.size = Vector2i(340, 220)
	add_child(dice_popup)

	var dice_vbox = VBoxContainer.new()
	dice_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_vbox.add_theme_constant_override("separation", 10)
	dice_popup.add_child(dice_vbox)

	dice_label = Label.new()
	dice_label.custom_minimum_size = Vector2(300, 70)
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dice_vbox.add_child(dice_label)

	dice_widget = DiceWidget.new()
	dice_vbox.add_child(dice_widget)

	rules_popup = RulesPopup.new()
	rules_popup.visible = false
	rules_popup.position = Vector2(100, 80)
	add_child(rules_popup)

	_apply_theme_styling()

func _on_toggle_sidebar_pressed() -> void:
	sidebar_collapsed = not sidebar_collapsed
	_apply_sidebar_layout()
	if map_canvas:
		map_canvas.queue_redraw()

func _apply_sidebar_layout() -> void:
	if sidebar_panel == null or tab_container == null:
		return

	tab_container.visible = not sidebar_collapsed
	if btn_toggle_panel != null:
		if sidebar_collapsed:
			btn_toggle_panel.text = "▴"
		else:
			btn_toggle_panel.text = "▾"

	if current_layout == 2: # PHONE: Bottom foldable sheet
		if sidebar_collapsed:
			sidebar_panel.position = Vector2(6, 605)
			sidebar_panel.custom_minimum_size = Vector2(363, 54)
			sidebar_panel.size = Vector2(363, 54)
		else:
			sidebar_panel.position = Vector2(6, 375)
			sidebar_panel.custom_minimum_size = Vector2(363, 284)
			sidebar_panel.size = Vector2(363, 284)
	else: # DESKTOP / TABLET: Floating right tactical panel
		if sidebar_collapsed:
			sidebar_panel.position = Vector2(1004, 74)
			sidebar_panel.custom_minimum_size = Vector2(260, 56)
			sidebar_panel.size = Vector2(260, 56)
		else:
			sidebar_panel.position = Vector2(912, 74)
			sidebar_panel.custom_minimum_size = Vector2(352, 632)
			sidebar_panel.size = Vector2(352, 632)

func _on_layout_changed(layout: int) -> void:
	current_layout = layout
	if (is_inside_tree() and has_node("/root/ThemeManager")):
		get_node("/root/ThemeManager").apply_font_scale_to_board(self)

	if layout == 2: # PHONE (375x667)
		map_panel.position = Vector2(0, 0)
		map_panel.custom_minimum_size = Vector2(375, 667)
		map_panel.size = Vector2(375, 667)
		if top_bar_panel:
			top_bar_panel.position = Vector2(6, 6)
			top_bar_panel.custom_minimum_size = Vector2(363, 44)
			top_bar_panel.size = Vector2(363, 44)
		if title_label_node:
			title_label_node.text = "🌍 TEG"
			title_label_node.add_theme_font_size_override("font_size", 14)
		if mode_option_button:
			mode_option_button.custom_minimum_size = Vector2(96, 28)
		if btn_rules_node:
			btn_rules_node.text = "📖"
			btn_rules_node.custom_minimum_size = Vector2(36, 28)
	else: # DESKTOP or TABLET — Fullscreen Map (1280x720) with superimposed HUD
		map_panel.position = Vector2(0, 0)
		map_panel.custom_minimum_size = Vector2(1280, 720)
		map_panel.size = Vector2(1280, 720)
		if top_bar_panel:
			top_bar_panel.position = Vector2(16, 12)
			top_bar_panel.custom_minimum_size = Vector2(1248, 52)
			top_bar_panel.size = Vector2(1248, 52)
		if title_label_node:
			title_label_node.text = "🌍 CRISIS — TEG"
			title_label_node.add_theme_font_size_override("font_size", 18)
		if mode_option_button:
			mode_option_button.custom_minimum_size = Vector2(128, 32)
		if btn_rules_node:
			btn_rules_node.text = "📖 Reglas"
			btn_rules_node.custom_minimum_size = Vector2(86, 32)

	_apply_sidebar_layout()

	if map_canvas:
		map_canvas.position = Vector2.ZERO
		map_canvas.size = map_panel.size
		map_canvas.queue_redraw()

	var vp_size := Vector2(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		var visible_sz = get_viewport().get_visible_rect().size
		if visible_sz.x > 0 and visible_sz.y > 0:
			vp_size = visible_sz

	var design_sz: Vector2 = map_panel.size if map_panel != null else Vector2(1280, 720)
	if vp_size.x < design_sz.x or vp_size.y < design_sz.y:
		var scale_x: float = (vp_size.x - 8.0) / design_sz.x
		var scale_y: float = (vp_size.y - 8.0) / design_sz.y
		var s: float = clampf(minf(scale_x, scale_y), 0.25, 1.0)
		scale = Vector2(s, s)
		position = Vector2(maxf(0.0, (vp_size.x - design_sz.x * s) * 0.5), maxf(0.0, (vp_size.y - design_sz.y * s) * 0.5))
	else:
		scale = Vector2.ONE
		position = Vector2.ZERO

func _on_viewport_size_changed() -> void:
	_on_layout_changed(current_layout)

func _get_map_transform() -> Dictionary:
	var canvas_size = map_canvas.size if map_canvas else Vector2(1280, 720)
	if current_layout == 2:
		var top_reserved: float = 54.0
		var bottom_reserved: float = 64.0 if sidebar_collapsed else 294.0
		var avail_w_m: float = maxf(canvas_size.x - 12.0, 200.0)
		var avail_h_m: float = maxf(canvas_size.y - top_reserved - bottom_reserved, 220.0)
		var sm: float = minf(avail_w_m / 880.0, avail_h_m / 540.0)
		var off_m := Vector2(
			6.0 + (avail_w_m - 920.0 * sm) * 0.5,
			top_reserved + (avail_h_m - 580.0 * sm) * 0.5
		)
		return { "scale": sm, "offset": off_m }

	# Fullscreen canvas (1280x720) with territories centered in the visible map viewport
	var usable_left: float = 14.0
	var usable_top: float = 68.0
	var right_reserved: float = 24.0 if sidebar_collapsed else 372.0
	var usable_w: float = maxf(canvas_size.x - usable_left - right_reserved, 720.0)
	var usable_h: float = maxf(canvas_size.y - usable_top - 16.0, 560.0)
	var scale_x: float = usable_w / 875.0
	var scale_y: float = usable_h / 545.0
	var s: float = minf(scale_x, scale_y)
	var offset := Vector2(
		usable_left + (usable_w - 925.0 * s) * 0.5,
		usable_top + (usable_h - 585.0 * s) * 0.5
	)
	return { "scale": s, "offset": offset }

func _to_screen(map_pos: Vector2, trans: Dictionary) -> Vector2:
	return trans["offset"] + map_pos * trans["scale"]

func _from_screen(screen_pos: Vector2, trans: Dictionary) -> Vector2:
	return (screen_pos - trans["offset"]) / trans["scale"]

# -------------------------------------------------------------------------
# MAP CANVAS DRAWING (Political World Map with Detailed Coastlines & Bathymetry)
# -------------------------------------------------------------------------
func _on_map_canvas_draw() -> void:
	var trans = _get_map_transform()
	var s: float = float(trans["scale"])
	var font = ThemeDB.fallback_font

	# 1. Political Atlas Ocean Backdrop & Cartographic Graticule
	var ocean_col = current_theme.board_color.darkened(0.10) if current_theme else Color("#102234")
	map_canvas.draw_rect(Rect2(Vector2.ZERO, map_canvas.size), ocean_col, true)

	var grid_col = current_theme.line_color if current_theme else Color("#7C9BB8")
	var faint_grid = Color(grid_col.r, grid_col.g, grid_col.b, 0.11)
	var equator_col = Color(grid_col.r, grid_col.g, grid_col.b, 0.22)

	# Fullscreen Lat/Long lines across the entire map_canvas
	for y_val in [120.0, 240.0, 360.0, 480.0, 600.0]:
		var line_c = equator_col if is_equal_approx(y_val, 360.0) else faint_grid
		map_canvas.draw_line(Vector2(0.0, y_val), Vector2(map_canvas.size.x, y_val), line_c, 1.0)
	for x_val in [180.0, 360.0, 540.0, 720.0, 900.0, 1080.0]:
		map_canvas.draw_line(Vector2(x_val, 0.0), Vector2(x_val, map_canvas.size.y), faint_grid, 1.0)

	# Subtle Compass Rose in the South Pacific
	_draw_compass_rose(_to_screen(Vector2(66.0, 492.0), trans), 22.0 * s, Color(grid_col.r, grid_col.g, grid_col.b, 0.32))

	# 2. Dual-Ring Coastal Bathymetry (Shallow Continental Shelf Glow + Drop Shadow)
	var shadow_offset := Vector2(3.5 * s, 4.5 * s)
	for i in range(30):
		var base_poly = TERRITORY_POLYGONS[i]
		var shadow_poly = PackedVector2Array()
		var coast_poly = PackedVector2Array()
		for pt in base_poly:
			var sp = _to_screen(pt, trans)
			shadow_poly.append(sp + shadow_offset)
			coast_poly.append(sp)
		coast_poly.append(_to_screen(base_poly[0], trans))
		map_canvas.draw_colored_polygon(shadow_poly, Color(0.01, 0.03, 0.07, 0.48))
		map_canvas.draw_polyline(coast_poly, Color(0.28, 0.68, 0.86, 0.16), maxf(10.0 * s, 4.5), true)
		map_canvas.draw_polyline(coast_poly, Color(0.55, 0.85, 0.96, 0.24), maxf(4.5 * s, 2.2), true)

	# 3. Draw Adjacencies & Sea Lanes (with wrap-around ocean edges for Canada<->Kamchatka and Chile<->Australia)
	for edge in ADJACENCIES:
		var t1: int = edge[0]
		var t2: int = edge[1]
		var c1 = _to_screen(TERRITORY_CENTERS[t1], trans)
		var c2 = _to_screen(TERRITORY_CENTERS[t2], trans)

		var is_sea = SEA_LANES.has(edge) or SEA_LANES.has([t2, t1])
		var is_active_connection = (selected_from == t1 and selected_to == t2) or (selected_from == t2 and selected_to == t1)
		var is_available_target = (selected_from == t1 and valid_targets.has(t2)) or (selected_from == t2 and valid_targets.has(t1))
		var is_wrap_edge = (t1 == 8 and t2 == 22) or (t1 == 22 and t2 == 8) or (t1 == 2 and t2 == 26) or (t1 == 26 and t2 == 2)

		var route_col := Color(0.32, 0.72, 0.92, 0.55)
		var route_width := maxf(1.5 * s, 1.2)
		if is_active_connection:
			var pulse_val = 0.7 + 0.3 * sin(pulse_time * 2.0)
			route_col = Color(1.0, 0.9, 0.2, pulse_val)
			route_width = maxf(3.2 * s, 2.2)
		elif is_available_target:
			var pulse_val = 0.6 + 0.4 * sin(pulse_time * 2.5)
			route_col = Color(0.2, 0.95, 0.4, pulse_val)
			route_width = maxf(2.4 * s, 1.8)

		if is_wrap_edge:
			var left_t: int = 8 if (t1 == 8 or t2 == 8) else 2
			var right_t: int = 22 if (t1 == 22 or t2 == 22) else 26
			var c_left = _to_screen(TERRITORY_CENTERS[left_t], trans)
			var c_right = _to_screen(TERRITORY_CENTERS[right_t], trans)
			var edge_left = _to_screen(Vector2(14.0, TERRITORY_CENTERS[left_t].y), trans)
			var edge_right = _to_screen(Vector2(906.0, TERRITORY_CENTERS[right_t].y), trans)
			_draw_dashed_line(c_left, edge_left, route_col, route_width, maxf(6.5 * s, 4.0), maxf(4.0 * s, 2.5))
			_draw_dashed_line(c_right, edge_right, route_col, route_width, maxf(6.5 * s, 4.0), maxf(4.0 * s, 2.5))
		elif is_active_connection or is_available_target:
			map_canvas.draw_line(c1, c2, route_col, route_width)
		elif is_sea:
			_draw_dashed_line(c1, c2, route_col, route_width, maxf(6.5 * s, 4.0), maxf(4.0 * s, 2.5))

	# 4. Draw Political Territory Polygons with Organic Coastlines & Borders
	for i in range(30):
		var base_poly = TERRITORY_POLYGONS[i]
		var screen_poly = PackedVector2Array()
		for pt in base_poly:
			screen_poly.append(_to_screen(pt, trans))

		var t_owner = territory_owners.get(i, 0)
		var continent_id = _get_territory_continent(i)
		var cont_col: Color = CONTINENTS_DATA[continent_id]["color"]

		var fill_color: Color
		if t_owner > 0 and PLAYER_COLORS.has(t_owner):
			var p_col: Color = PLAYER_COLORS[t_owner]
			# Blend political player color with regional continent hue so each country has distinct political shading
			fill_color = p_col.lerp(cont_col, 0.26)
			fill_color.a = 0.86
		else:
			fill_color = Color(cont_col.r, cont_col.g, cont_col.b, 0.62)

		# State highlights
		if selected_from == i:
			var pulse_factor = 0.85 + 0.15 * sin(pulse_time)
			fill_color = fill_color.lightened(0.30)
			fill_color.a = pulse_factor
		elif selected_to == i:
			fill_color = Color(0.2, 0.9, 0.4, 0.90)
		elif valid_targets.has(i):
			var pulse_val = 0.65 + 0.25 * sin(pulse_time * 1.5)
			if current_phase == "Attack":
				fill_color = fill_color.blend(Color(1.0, 0.22, 0.22, pulse_val * 0.42))
			else:
				fill_color = fill_color.blend(Color(0.2, 0.9, 0.4, pulse_val * 0.42))
		elif hovered_territory == i:
			fill_color = fill_color.lightened(0.18)

		map_canvas.draw_colored_polygon(screen_poly, fill_color)

		# Political Map Border: Crisp dark ink border + inner continental highlight
		var stroke_color = Color(0.08, 0.11, 0.16, 0.92)
		var stroke_width = maxf(1.5 * s, 1.1)

		if selected_from == i:
			stroke_color = current_theme.select_color if current_theme else Color(1.0, 0.9, 0.2)
			stroke_width = maxf(3.0 * s, 2.2)
		elif selected_to == i:
			stroke_color = current_theme.valid_move_color if current_theme else Color(0.2, 0.9, 0.5)
			stroke_width = maxf(3.0 * s, 2.2)
		elif valid_targets.has(i):
			stroke_color = Color(0.3, 0.95, 0.45)
			stroke_width = maxf(2.3 * s, 1.8)
		elif hovered_territory == i:
			stroke_color = Color.WHITE
			stroke_width = maxf(2.1 * s, 1.6)

		var poly_closed = Array(screen_poly)
		poly_closed.append(screen_poly[0])
		map_canvas.draw_polyline(PackedVector2Array(poly_closed), stroke_color, stroke_width, true)

	# 5. Draw Tactical Shields (Troop Count + Short 3-Letter Code — Zero Overlap)
	for i in range(30):
		var center_pos = _to_screen(TERRITORY_CENTERS[i], trans)
		var t_owner = territory_owners.get(i, 0)
		var armies = territory_armies.get(i, 0)
		var badge_radius = clampf(11.5 * s, 8.5, 14.5)
		var badge_color: Color = PLAYER_COLORS.get(t_owner, Color(0.25, 0.25, 0.30))
		var is_focus = (i == selected_from or i == selected_to or i == hovered_territory)

		# Outer metallic/dark shield rim
		var rim_col = Color(1.0, 0.92, 0.35, 0.98) if is_focus else Color(0.06, 0.09, 0.14, 0.94)
		map_canvas.draw_circle(center_pos, badge_radius + maxf(1.8 * s, 1.4), rim_col)
		map_canvas.draw_circle(center_pos, badge_radius, badge_color.darkened(0.12))
		map_canvas.draw_circle(center_pos, badge_radius - maxf(1.6 * s, 1.1), badge_color.lightened(0.14))

		# Army count text inside shield
		var count_str = str(armies)
		var font_size = int(clampf(11.0 * s, 9.0, 14.0))
		var str_size = font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center_pos + Vector2(-str_size.x * 0.5, str_size.y * 0.32)
		map_canvas.draw_string(font, text_pos, count_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

		# Compact 3-letter Short Code Tag right below the shield
		var code_str: String = TERRITORY_CODES[i]
		var code_font_size = int(clampf(8.5 * s, 7.0, 10.0))
		var code_size = font.get_string_size(code_str, HORIZONTAL_ALIGNMENT_CENTER, -1, code_font_size)
		var pad_x = maxf(2.8 * s, 2.0)
		var pad_y = maxf(1.0 * s, 1.0)
		var pill_rect = Rect2(
			center_pos.x - code_size.x * 0.5 - pad_x,
			center_pos.y + badge_radius + maxf(1.5 * s, 1.0),
			code_size.x + pad_x * 2.0,
			code_size.y + pad_y * 2.0
		)
		var pill_bg = Color(0.12, 0.18, 0.26, 0.92) if is_focus else Color(0.05, 0.08, 0.13, 0.82)
		var pill_border = Color(0.95, 0.85, 0.35, 0.85) if is_focus else Color(0.45, 0.58, 0.72, 0.45)
		map_canvas.draw_rect(pill_rect, pill_bg, true)
		map_canvas.draw_rect(pill_rect, pill_border, false, 1.0)
		var code_text_pos = Vector2(
			center_pos.x - code_size.x * 0.5,
			pill_rect.position.y + code_size.y - pad_y * 0.5
		)
		map_canvas.draw_string(font, code_text_pos, code_str, HORIZONTAL_ALIGNMENT_CENTER, -1, code_font_size, Color(0.94, 0.96, 1.0))

	# 6. Foreground Callout for Selected / Hovered Territory (Full Name + Troops)
	var focus_ids: Array[int] = []
	if selected_from != -1:
		focus_ids.append(selected_from)
	if selected_to != -1 and not focus_ids.has(selected_to):
		focus_ids.append(selected_to)
	if hovered_territory != -1 and not focus_ids.has(hovered_territory):
		focus_ids.append(hovered_territory)

	for fid in focus_ids:
		var c_pos = _to_screen(TERRITORY_CENTERS[fid], trans)
		var full_name: String = TERRITORY_NAMES[fid]
		var f_armies: int = territory_armies.get(fid, 0)
		var callout_txt = "%s (%d)" % [full_name, f_armies]
		var callout_fs = int(clampf(11.0 * s, 10.0, 13.0))
		var c_size = font.get_string_size(callout_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, callout_fs)
		var badge_r = clampf(11.5 * s, 8.5, 14.5)
		var box_w = c_size.x + 14.0
		var box_h = c_size.y + 6.0
		var box_x = clampf(c_pos.x - box_w * 0.5, 8.0, map_canvas.size.x - box_w - 8.0)
		var box_y = maxf(c_pos.y - badge_r - box_h - 5.0, 58.0)
		var box_rect = Rect2(box_x, box_y, box_w, box_h)
		map_canvas.draw_rect(box_rect, Color(0.06, 0.10, 0.16, 0.95), true)
		map_canvas.draw_rect(box_rect, Color(0.98, 0.86, 0.32, 0.95), false, 1.5)
		map_canvas.draw_string(
			font,
			Vector2(box_x + 7.0, box_y + c_size.y),
			callout_txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			callout_fs,
			Color(1.0, 0.95, 0.75)
		)

	# 7. Bottom-Left Tactical Info Banner (Full territory details)
	_draw_map_info_banner(font)

func _draw_compass_rose(center: Vector2, radius: float, col: Color) -> void:
	map_canvas.draw_arc(center, radius, 0.0, TAU, 32, col, 1.2)
	map_canvas.draw_arc(center, radius * 0.65, 0.0, TAU, 24, col, 1.0)
	map_canvas.draw_line(center + Vector2(0, -radius * 1.25), center + Vector2(0, radius * 1.25), col, 1.4)
	map_canvas.draw_line(center + Vector2(-radius * 1.25, 0), center + Vector2(radius * 1.25, 0), col, 1.4)
	map_canvas.draw_line(center + Vector2(-radius * 0.75, -radius * 0.75), center + Vector2(radius * 0.75, radius * 0.75), col, 1.0)
	map_canvas.draw_line(center + Vector2(radius * 0.75, -radius * 0.75), center + Vector2(-radius * 0.75, radius * 0.75), col, 1.0)

func _draw_map_info_banner(font: Font) -> void:
	var inspect_id: int = hovered_territory if hovered_territory != -1 else (selected_to if selected_to != -1 else selected_from)
	var banner_y: float = map_canvas.size.y - 36.0
	if current_layout == 2:
		banner_y = (sidebar_panel.position.y - 32.0) if sidebar_panel != null else (map_canvas.size.y - 36.0)

	if inspect_id != -1 and inspect_id >= 0 and inspect_id < 30:
		var t_name: String = TERRITORY_NAMES[inspect_id]
		var t_code: String = TERRITORY_CODES[inspect_id]
		var t_owner: int = territory_owners.get(inspect_id, 0)
		var t_armies: int = territory_armies.get(inspect_id, 0)
		var cont_id: int = _get_territory_continent(inspect_id)
		var cont_name: String = CONTINENTS_DATA[cont_id]["name"]
		var owner_name: String = PLAYER_NAMES.get(t_owner, "Neutral")
		var info_str = "📍 [%s] %s  ·  %s  ·  Dueño: %s  ·  %d tropas" % [t_code, t_name, cont_name, owner_name, t_armies]
		var fs: int = 10 if current_layout == 2 else 12
		var t_sz = font.get_string_size(info_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var b_rect = Rect2(10.0, banner_y, minf(t_sz.x + 20.0, map_canvas.size.x - 20.0), 26.0)
		map_canvas.draw_rect(b_rect, Color(0.06, 0.10, 0.16, 0.90), true)
		map_canvas.draw_rect(b_rect, CONTINENTS_DATA[cont_id]["color"], false, 1.5)
		map_canvas.draw_string(font, Vector2(b_rect.position.x + 10.0, b_rect.position.y + 18.0), info_str, HORIZONTAL_ALIGNMENT_LEFT, b_rect.size.x - 16.0, fs, Color.WHITE)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var dir = (to - from)
	var dist = dir.length()
	if dist <= 0.001:
		return
	var norm = dir / dist
	var curr = 0.0
	while curr < dist:
		var end_p = min(curr + dash_len, dist)
		map_canvas.draw_line(from + norm * curr, from + norm * end_p, color, width)
		curr += dash_len + gap_len

func _get_territory_continent(t_id: int) -> int:
	for c in CONTINENTS_DATA:
		if c["territories"].has(t_id):
			return c["id"]
	return 0

func _on_map_canvas_gui_input(event: InputEvent) -> void:
	var trans = _get_map_transform()

	if event is InputEventMouseMotion:
		var mouse_map = _from_screen(event.position, trans)
		var found_t = -1
		for i in range(30):
			if Geometry2D.is_point_in_polygon(mouse_map, TERRITORY_POLYGONS[i]):
				found_t = i
				break
			elif TERRITORY_CENTERS[i].distance_to(mouse_map) <= 24.0:
				found_t = i
				break
		if found_t != hovered_territory:
			hovered_territory = found_t
			map_canvas.queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_map = _from_screen(event.position, trans)
		for i in range(30):
			if Geometry2D.is_point_in_polygon(mouse_map, TERRITORY_POLYGONS[i]) or TERRITORY_CENTERS[i].distance_to(mouse_map) <= 24.0:
				_on_territory_clicked(i)
				break

func _on_territory_clicked(t_id: int) -> void:
	var t_owner = territory_owners.get(t_id, 0)
	var armies = territory_armies.get(t_id, 0)

	if current_phase == "PlaceArmies" or current_phase.begins_with("PlaceArmies") or current_phase == "Placement":
		if t_owner == current_player_id:
			selected_from = t_id
			selected_to = -1
			valid_targets.clear()
			action_info_label.text = "Seleccionado: %s (%d tropas). Haz click en '+1 Tropa' para colocar." % [
				TERRITORY_NAMES[t_id], armies
			]
		else:
			action_info_label.text = "%s no te pertenece (dueño: Jugador %d)." % [TERRITORY_NAMES[t_id], t_owner]

	elif current_phase == "Attack":
		if selected_from == -1:
			if t_owner == current_player_id:
				if armies > 1:
					selected_from = t_id
					_calculate_valid_attack_targets(t_id)
					action_info_label.text = "Atacando desde: %s (%d tropas). Elige un territorio enemigo adyacente." % [
						TERRITORY_NAMES[t_id], armies
					]
				else:
					action_info_label.text = "%s solo tiene 1 ejército (se necesitan >1 para atacar)." % TERRITORY_NAMES[t_id]
			else:
				action_info_label.text = "Debes seleccionar uno de tus territorios con al menos 2 ejércitos."
		else:
			if t_owner == current_player_id:
				# Switch attacking origin
				if armies > 1:
					selected_from = t_id
					_calculate_valid_attack_targets(t_id)
					selected_to = -1
					action_info_label.text = "Cambiado origen a: %s. Elige objetivo enemigo." % TERRITORY_NAMES[t_id]
				else:
					action_info_label.text = "%s solo tiene 1 ejército." % TERRITORY_NAMES[t_id]
			elif valid_targets.has(t_id):
				selected_to = t_id
				var max_dice = min(3, territory_armies.get(selected_from, 1) - 1)
				attack_dice_spinbox.max_value = max_dice
				attack_dice_spinbox.value = max_dice
				action_info_label.text = "Listo para atacar: %s ⚔️ %s (%d tropas enemigas). Dados: %d." % [
					TERRITORY_NAMES[selected_from], TERRITORY_NAMES[selected_to], armies, max_dice
				]
			else:
				action_info_label.text = "%s no es adyacente o no es un objetivo válido." % TERRITORY_NAMES[t_id]

	elif current_phase == "Fortify":
		if selected_from == -1:
			if t_owner == current_player_id:
				if armies > 1:
					selected_from = t_id
					_calculate_valid_fortify_targets(t_id)
					fortify_armies_spinbox.max_value = armies - 1
					fortify_armies_spinbox.value = 1
					action_info_label.text = "Fortificando desde: %s (%d tropas). Selecciona territorio destino propio." % [
						TERRITORY_NAMES[t_id], armies
					]
				else:
					action_info_label.text = "%s no tiene tropas sobrantes para mover." % TERRITORY_NAMES[t_id]
			else:
				action_info_label.text = "Selecciona un territorio propio."
		else:
			if valid_targets.has(t_id):
				selected_to = t_id
				action_info_label.text = "Mover tropas de %s ➡️ %s. Selecciona cantidad y presiona Fortificar." % [
					TERRITORY_NAMES[selected_from], TERRITORY_NAMES[selected_to]
				]
			elif t_owner == current_player_id:
				selected_from = t_id
				_calculate_valid_fortify_targets(t_id)
				selected_to = -1

	map_canvas.queue_redraw()

func _calculate_valid_attack_targets(from_id: int) -> void:
	valid_targets.clear()
	for edge in ADJACENCIES:
		var other = -1
		if edge[0] == from_id:
			other = edge[1]
		elif edge[1] == from_id:
			other = edge[0]
		if other != -1:
			if territory_owners.get(other, 0) != current_player_id:
				valid_targets.append(other)

func _calculate_valid_fortify_targets(from_id: int) -> void:
	valid_targets.clear()
	for edge in ADJACENCIES:
		var other = -1
		if edge[0] == from_id:
			other = edge[1]
		elif edge[1] == from_id:
			other = edge[0]
		if other != -1:
			if territory_owners.get(other, 0) == current_player_id:
				valid_targets.append(other)

# -------------------------------------------------------------------------
# GAME ACTIONS (Place, Attack, Fortify, EndPhase, Exchange)
# -------------------------------------------------------------------------
func _on_btn_place_pressed() -> void:
	_place_armies(1)

func _place_armies(count: int) -> void:
	var target_t = selected_from
	if target_t == -1 or territory_owners.get(target_t, 0) != current_player_id:
		for t in territory_owners:
			if territory_owners[t] == current_player_id:
				target_t = t
				break
	if target_t != -1:
		var place_count = max(1, count)
		if armies_remaining_to_place > 0:
			place_count = min(place_count, armies_remaining_to_place)
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "PlaceArmiesCommand",
			"player": current_player_id,
			"territory": target_t,
			"count": place_count
		}))
		_sync_all_from_bridge()
		_update_ui_state()

func _on_btn_attack_pressed() -> void:
	_is_human_attacking = true
	if selected_from != -1 and selected_to != -1:
		var dice_count = int(attack_dice_spinbox.value)
		# 1. Declare Attack
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "DeclareAttackCommand",
			"player": current_player_id,
			"from": selected_from,
			"to": selected_to,
			"dice": dice_count
		}))
		# 2. Roll Attack
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "RollAttackCommand",
			"player": current_player_id
		}))
	else:
		# Fallback general attack roll
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "RollAttackCommand",
			"player": current_player_id
		}))
	_is_human_attacking = false
	_sync_all_from_bridge()
	_update_ui_state()

func _on_btn_fortify_pressed() -> void:
	if selected_from != -1 and selected_to != -1:
		var armies_to_move = int(fortify_armies_spinbox.value)
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "FortifyCommand",
			"player": current_player_id,
			"from": selected_from,
			"to": selected_to,
			"armies": armies_to_move
		}))
		selected_from = -1
		selected_to = -1
		valid_targets.clear()
		_sync_all_from_bridge()
		_update_ui_state()

func _on_btn_end_phase_pressed() -> void:
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	bridge.send_command_json(current_player_id, JSON.stringify({
		"command_type": "EndPhaseCommand",
		"player": current_player_id
	}))
	_sync_all_from_bridge()
	_update_ui_state()

func _on_btn_exchange_pressed() -> void:
	if selected_card_indices.size() == 3:
		bridge.send_command_json(current_player_id, JSON.stringify({
			"command_type": "ExchangeCardsCommand",
			"player": current_player_id,
			"card_indices": selected_card_indices
		}))
		# Remove exchanged cards locally
		var cards = player_cards.get(current_player_id, [])
		var sorted_idxs = selected_card_indices.duplicate()
		sorted_idxs.sort()
		sorted_idxs.reverse()
		for idx in sorted_idxs:
			if idx < cards.size():
				cards.remove_at(idx)
		selected_card_indices.clear()
		_sync_all_from_bridge()
		_update_ui_state()

# -------------------------------------------------------------------------
# STATE SYNCHRONIZATION & BRIDGE SIGNALS
# -------------------------------------------------------------------------
func _sync_all_from_bridge() -> void:
	if bridge == null:
		return
	current_player_id = bridge.current_player()

	if bridge.has_method("get_crisis_territory_owner"):
		for i in range(30):
			var o = bridge.call("get_crisis_territory_owner", i)
			var a = bridge.call("get_crisis_territory_armies", i)
			territory_owners[i] = o
			territory_armies[i] = a
			_update_territory_label(i)

	if bridge.has_method("get_crisis_remaining_armies"):
		armies_remaining_to_place = int(bridge.call("get_crisis_remaining_armies"))

	if bridge.has_method("get_crisis_turn_phase"):
		var ph_str = str(bridge.call("get_crisis_turn_phase"))
		if ph_str != "":
			current_phase = ph_str

	_render_cards_deck()
	_update_objective_progress()
	if map_canvas:
		map_canvas.queue_redraw()

func _format_phase_es(phase_str: String) -> String:
	if phase_str.begins_with("PlaceArmies") or phase_str == "Placement":
		return "Refuerzos"
	elif phase_str == "Attack":
		return "Ataque"
	elif phase_str == "Fortify":
		return "Fortificación"
	return phase_str

func _update_ui_state() -> void:
	if bridge != null:
		current_player_id = bridge.current_player()
	var is_active = (winner == -1)

	var is_placement = current_phase == "PlaceArmies" or current_phase.begins_with("PlaceArmies") or current_phase == "Placement"
	var is_attack = current_phase == "Attack"
	var is_fortify = current_phase == "Fortify"

	btn_place.disabled = not (is_active and is_placement)
	btn_place_5.disabled = not (is_active and is_placement and armies_remaining_to_place >= 5)
	btn_place_all.disabled = not (is_active and is_placement and armies_remaining_to_place > 0)
	btn_attack.disabled = not (is_active and is_attack)
	btn_fortify.disabled = not (is_active and is_fortify)
	btn_end_phase.disabled = not is_active
	btn_exchange.disabled = not (is_active and is_placement and selected_card_indices.size() == 3)

	if action_title_label:
		action_title_label.text = "Fase: %s%s" % [
			_format_phase_es(current_phase),
			(" (%d disponibles)" % armies_remaining_to_place) if is_placement and armies_remaining_to_place > 0 else ""
		]

	var p1_count: int = 0
	var p2_count: int = 0
	for t_id in territory_owners:
		if territory_owners[t_id] == 1:
			p1_count += 1
		elif territory_owners[t_id] == 2:
			p2_count += 1

	player_stats_label.text = "Turno: %s · %s %s\n🛡️ Rojo: %d terr. | Azul: %d terr." % [
		PLAYER_NAMES.get(current_player_id, "J" + str(current_player_id)),
		_format_phase_es(current_phase),
		("(%d)" % armies_remaining_to_place) if is_placement and armies_remaining_to_place > 0 else "",
		p1_count,
		p2_count
	]

	if status_label:
		if winner != -1:
			status_label.text = "¡Partida Finalizada! Ganador: %s" % PLAYER_NAMES.get(winner, "Jugador " + str(winner))
		else:
			status_label.text = "Turno %s — Fase %s" % [PLAYER_NAMES.get(current_player_id, "P" + str(current_player_id)), current_phase]

	if turn_indicator:
		var p_name: String = PLAYER_NAMES.get(current_player_id, "Jugador %d" % current_player_id)
		var p_col: Color = PLAYER_COLORS.get(current_player_id, Color.WHITE)
		turn_indicator.set_turn(current_player_id, p_name, p_col)

	_update_objective_progress()
	if map_canvas:
		map_canvas.queue_redraw()

func _update_territory_label(t_id: int) -> void:
	if not territory_labels.has(t_id):
		return
	var lbl: Label = territory_labels[t_id]
	var t_owner: int = territory_owners.get(t_id, 0)
	var armies: int = territory_armies.get(t_id, 0)
	lbl.text = "%s\n[P%d: %d]" % [TERRITORY_NAMES[t_id], t_owner, armies]

func _on_armies_placed(player_id: int, territory_id: int, count: int, remaining: int) -> void:
	territory_owners[territory_id] = player_id
	territory_armies[territory_id] = territory_armies.get(territory_id, 0) + count
	armies_remaining_to_place = remaining
	_update_territory_label(territory_id)
	_update_ui_state()

func _on_attack_resolved(from_id: int, to_id: int, attacker_rolls: Array, defender_rolls: Array, attacker_losses: int, defender_losses: int) -> void:
	var att_str = " ".join(attacker_rolls.map(func(r): return "🎲" + str(r)))
	var def_str = " ".join(defender_rolls.map(func(r): return "🎲" + str(r)))

	var summary_txt = "Ataque: %s ⚔️ %s\nAtacante: [%s] (-%d tropas)\nDefensor: [%s] (-%d tropas)" % [
		TERRITORY_NAMES[from_id], TERRITORY_NAMES[to_id], att_str, attacker_losses, def_str, defender_losses
	]
	dice_label.text = summary_txt
	if dice_widget != null and attacker_rolls.size() > 0:
		dice_widget.show_roll(attacker_rolls)
	if (not is_vs_ai or _is_human_attacking) and not OS.has_feature("headless"):
		dice_popup.popup_centered()
	_sync_all_from_bridge()
	_update_ui_state()

func _on_territory_conquered(player_id: int, territory_id: int, _from_armies: int, to_armies: int) -> void:
	territory_owners[territory_id] = player_id
	territory_armies[territory_id] = to_armies
	_update_territory_label(territory_id)

	# Draw a random card upon conquest
	var random_type = randi() % 3
	var cards = player_cards.get(player_id, [])
	cards.append({ "territory": territory_id, "card_type": random_type })
	player_cards[player_id] = cards
	_sync_all_from_bridge()
	_update_ui_state()

func _on_player_eliminated(player_id: int, by_player_id: int) -> void:
	action_info_label.text = "💀 ¡El Jugador %d fue eliminado por el Jugador %d!" % [player_id, by_player_id]
	_sync_all_from_bridge()
	_update_ui_state()

func _on_phase_changed(player_id: int, new_phase: String) -> void:
	current_player_id = player_id
	current_phase = new_phase
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	_sync_all_from_bridge()
	_update_ui_state()

func _on_turn_changed(player_id: int) -> void:
	current_player_id = player_id
	selected_from = -1
	selected_to = -1
	valid_targets.clear()
	_sync_all_from_bridge()
	_update_ui_state()

func _on_cards_exchanged(player_id: int, armies_gained: int) -> void:
	exchange_count += 1
	action_info_label.text = "🎉 ¡Jugador %d canjeó tarjetas y obtuvo +%d ejércitos!" % [player_id, armies_gained]
	_sync_all_from_bridge()
	_update_ui_state()

func _on_crisis_game_over(winner_id: int, _objective: String) -> void:
	winner = winner_id
	_update_ui_state()
	var overlay = preload("res://game_over_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_winner(winner_id)

func _on_game_over(w: int) -> void:
	_sfx_victory_fanfare()
	winner = w
	_update_ui_state()

func _on_move_rejected(reason: String) -> void:
	_sfx_error_buzz()
	action_info_label.text = "⚠️ Acción no permitida: %s" % reason
	if status_label:
		status_label.text = "Inválido: %s" % reason

func _on_event_json(json_str: String) -> void:
	var parser = JSON.new()
	if parser.parse(json_str) == OK:
		var evt = parser.data
		if evt is Dictionary:
			var et = evt.get("event_type", evt.get("command_type", ""))
			if "PhaseChangedEvent" in et:
				current_phase = evt.get("new_phase", current_phase)
			elif "TerritoryConqueredEvent" in et:
				var p = int(evt.get("player", -1))
				var card = evt.get("card_drawn", null)
				if card != null and p != -1:
					if not player_cards.has(p):
						player_cards[p] = []
					player_cards[p].append(card)
					_render_cards_deck()
					if action_info_label:
						var t_id = int(card.get("territory", 0))
						var t_name = TERRITORY_NAMES[t_id] if t_id >= 0 and t_id < TERRITORY_NAMES.size() else "Territorio %d" % t_id
						action_info_label.text = "🃏 ¡Conquista exitosa! Tarjeta obtenida: %s" % t_name
				_sync_all_from_bridge()
			elif "CardsExchangedEvent" in et:
				_sync_all_from_bridge()
	_update_ui_state()

# -------------------------------------------------------------------------
# CARDS & OBJECTIVE UI VISUALIZATION (Point d)
# -------------------------------------------------------------------------
func _render_cards_deck() -> void:
	if not cards_container:
		return
	for child in cards_container.get_children():
		child.queue_free()

	var cards = player_cards.get(current_player_id, [])
	for idx in range(cards.size()):
		var card = cards[idx]
		var t_id = card.get("territory", 0)
		var c_type = card.get("card_type", 0)
		var type_info = CARD_TYPES.get(c_type, { "name": "Infantería", "icon": "🪖" })

		var card_btn = Button.new()
		card_btn.custom_minimum_size = Vector2(82, 106)
		card_btn.toggle_mode = true
		card_btn.button_pressed = selected_card_indices.has(idx)

		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_btn.add_child(card_vbox)

		var icon_lbl = Label.new()
		icon_lbl.text = type_info["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(icon_lbl)

		var type_lbl = Label.new()
		type_lbl.text = type_info["name"]
		type_lbl.add_theme_font_size_override("font_size", 10)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(type_lbl)

		var terr_lbl = Label.new()
		terr_lbl.text = TERRITORY_NAMES[t_id] if t_id < TERRITORY_NAMES.size() else "Territorio"
		terr_lbl.add_theme_font_size_override("font_size", 10)
		terr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		terr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(terr_lbl)

		var c_idx = idx
		card_btn.toggled.connect(func(pressed: bool): _on_card_toggled(c_idx, pressed))
		cards_container.add_child(card_btn)

	var next_bonus = _get_next_exchange_bonus()
	btn_exchange.text = "🔄 Canjear (+%d Tropas)" % next_bonus

func _on_card_toggled(idx: int, pressed: bool) -> void:
	if pressed:
		if not selected_card_indices.has(idx):
			if selected_card_indices.size() < 3:
				selected_card_indices.append(idx)
			else:
				selected_card_indices[2] = idx
	else:
		selected_card_indices.erase(idx)

	_validate_selected_card_combination()
	_render_cards_deck()
	_update_ui_state()

func _validate_selected_card_combination() -> void:
	var cards = player_cards.get(current_player_id, [])
	if selected_card_indices.size() == 3:
		var t1 = cards[selected_card_indices[0]].get("card_type", 0)
		var t2 = cards[selected_card_indices[1]].get("card_type", 0)
		var t3 = cards[selected_card_indices[2]].get("card_type", 0)
		var has_wild = (t1 == 3 or t2 == 3 or t3 == 3)
		var three_same = (t1 == t2 and t2 == t3)
		var one_of_each = (t1 != t2 and t2 != t3 and t1 != t3)

		if has_wild or three_same or one_of_each:
			cards_info_label.text = "✅ ¡Combinación Válida! (+%d tropas al canjear)" % _get_next_exchange_bonus()
			cards_info_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
			btn_exchange.disabled = false
		else:
			cards_info_label.text = "❌ Combinación no válida. Deben ser 3 del mismo tipo o 1 de cada uno."
			cards_info_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
			btn_exchange.disabled = true
	else:
		cards_info_label.text = "Selecciona 3 tarjetas (%d/3 seleccionadas)." % selected_card_indices.size()
		cards_info_label.remove_theme_color_override("font_color")
		btn_exchange.disabled = true

func _get_next_exchange_bonus() -> int:
	match exchange_count:
		0: return 4
		1: return 6
		2: return 8
		_: return 8 + (exchange_count - 2) * 5

func _update_objective_progress() -> void:
	var obj = player_objectives.get(current_player_id, player_objectives.get(1, {}))
	if not obj:
		return

	objective_title_label.text = obj.get("title", "Misión Secreta")
	objective_desc_label.text = obj.get("desc", "")

	var owned_count = 0
	for t in territory_owners:
		if territory_owners[t] == current_player_id:
			owned_count += 1

	if obj.get("target_type") == "continents":
		var target_conts = obj.get("continents", [])
		var complete_conts = 0
		var total_conts = target_conts.size()
		for c_id in target_conts:
			var cont_terrs = CONTINENTS_DATA[c_id]["territories"]
			var all_owned = true
			for tid in cont_terrs:
				if territory_owners.get(tid, 0) != current_player_id:
					all_owned = false
					break
			if all_owned:
				complete_conts += 1
		objective_progress_bar.max_value = total_conts
		objective_progress_bar.value = complete_conts
		objective_progress_label.text = "%d / %d continentes dominados" % [complete_conts, total_conts]
	else:
		var target_num = obj.get("target_count", 24)
		objective_progress_bar.max_value = target_num
		objective_progress_bar.value = min(owned_count, target_num)
		objective_progress_label.text = "%d / %d territorios conquistados (%d%%)" % [
			owned_count, target_num, int(float(owned_count) / float(target_num) * 100.0)
		]

# --- Conexión de eventos sonoros procedurales (AudioManager) ---
func _sfx_piece_slide() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_slide()

func _sfx_piece_place() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place()

func _sfx_capture(world_pos: Vector2 = Vector2(240, 240)) -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_piece_place(2.0)
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.45
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 110.0
	particles.color = Color(1.0, 0.85, 0.3, 0.9)
	add_child(particles)
	if is_inside_tree():
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)

func _sfx_dice_roll() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_dice_roll()

func _sfx_card_flip() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_card_flip()

func _sfx_check_alert() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_check_alert()

func _sfx_victory_fanfare() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_victory_fanfare()

func _sfx_error_buzz() -> void:
	if (is_inside_tree() and has_node("/root/AudioManager")):
		get_node("/root/AudioManager").play_error_buzz()

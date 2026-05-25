Config = {}

-- Ustawienia otwierania menu
Config.OpenCommand = 'skills'
Config.DefaultKey = 'K'
Config.OpenDescription = 'Otwórz Drzewko Umiejętności'

-- Ustawienia progresji
Config.Leveling = {
    BaseXP = 100,
    GrowthPerLevel = 50,
    SkillPointsPerLevel = 1
}

-- Definicja umiejętności (łatwa rozbudowa)
Config.Skills = {
    fishing_1 = {
        id = 'fishing_1',
        name = 'Wędkarz I',
        description = '+10% szans na lepszą rybę.',
        cost = 1,
        requirement = nil,
        x = 18,
        y = 60,
        color = '#9d4edd',
        category = 'gathering'
    },
    fishing_2 = {
        id = 'fishing_2',
        name = 'Wędkarz II',
        description = '+20% szans na rzadką rybę.',
        cost = 2,
        requirement = 'fishing_1',
        x = 35,
        y = 45,
        color = '#9d4edd',
        category = 'gathering'
    },
    combat_1 = {
        id = 'combat_1',
        name = 'Taktyk I',
        description = 'Lepsza kontrola walki.',
        cost = 1,
        requirement = nil,
        x = 50,
        y = 70,
        color = '#3a86ff',
        category = 'combat'
    },
    combat_2 = {
        id = 'combat_2',
        name = 'Taktyk II',
        description = 'Zaawansowana skuteczność bojowa.',
        cost = 2,
        requirement = 'combat_1',
        x = 65,
        y = 52,
        color = '#3a86ff',
        category = 'combat'
    },
    crafting_1 = {
        id = 'crafting_1',
        name = 'Rzemieślnik I',
        description = 'Mniejsze zużycie materiałów.',
        cost = 1,
        requirement = nil,
        x = 28,
        y = 28,
        color = '#38b000',
        category = 'crafting'
    },
    crafting_2 = {
        id = 'crafting_2',
        name = 'Rzemieślnik II',
        description = 'Wyższa jakość wytwarzanych przedmiotów.',
        cost = 2,
        requirement = 'crafting_1',
        x = 45,
        y = 16,
        color = '#38b000',
        category = 'crafting'
    },
    medical_1 = {
        id = 'medical_1',
        name = 'Ratownik I',
        description = 'Szybsza pomoc medyczna.',
        cost = 1,
        requirement = nil,
        x = 72,
        y = 30,
        color = '#ffbe0b',
        category = 'medical'
    },
    medical_2 = {
        id = 'medical_2',
        name = 'Ratownik II',
        description = 'Większa skuteczność leczenia.',
        cost = 2,
        requirement = 'medical_1',
        x = 86,
        y = 18,
        color = '#ffbe0b',
        category = 'medical'
    }
}

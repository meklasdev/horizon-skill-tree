Config = {}

--[[
    Zależności:
    - Wymagane: es_extended, oxmysql
    - Opcjonalne: ox_lib (UI/notify), ox_target (interakcje)

    Każdy skill w Config.Skills może mieć pola:
    id, name, description, cost, requirement, x, y, color, category, effects, triggers

    effects.combat:
    - weaponDamage = 0.02  -- +2% dmg broni
    - meleeDamage = 0.04   -- +4% dmg melee

    triggers:
    - server = 'twoj:event:server'
    - client = 'twoj:event:client'
]]

-- Ustawienia otwierania menu
Config.OpenCommand = 'skills'
Config.DefaultKey = 'K'
Config.OpenDescription = 'Otwórz Drzewko Umiejętności'

-- Gotowe triggery (możesz podmienić pod swój ekosystem)
Config.Triggers = {
    OpenMenuClient = 'horizon_skill_tree:client:toggleMenu',
    SyncCombatServer = 'horizon_skill_tree:server:syncCombat',
    OnSkillUnlockServer = 'horizon_skill_tree:trigger:skillUnlocked',
    OnSkillUnlockClient = 'horizon_skill_tree:trigger:skillUnlockedClient',
    OnLevelUpServer = 'horizon_skill_tree:trigger:levelUp'
}

-- Natywne bonusy walki z limitem anti-OP
Config.Combat = {
    Enabled = true,
    MaxWeaponBonus = 0.05, -- max +5%
    MaxMeleeBonus = 0.08,  -- max +8%
    ReapplyOnSpawn = true
}

-- Publiczne eventy net (klient -> serwer). Trzymaj wyłączone jeśli nie są wymagane.
Config.Security = {
    AllowClientAddXPEvent = false,
    AllowClientSkillPointEvents = false
}

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
        category = 'gathering',
        effects = {
            fishing = {
                rareChanceMultiplier = 1.10,
                xpMultiplier = 1.05
            }
        }
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
        category = 'gathering',
        effects = {
            fishing = {
                rareChanceMultiplier = 1.20,
                xpMultiplier = 1.10
            }
        }
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
        category = 'combat',
        effects = {
            combat = {
                weaponDamage = 0.02,
                meleeDamage = 0.04
            }
        },
        triggers = {
            server = 'horizon_skill_tree:combat:unlocked',
            client = 'horizon_skill_tree:combat:unlockedClient'
        }
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
        category = 'combat',
        effects = {
            combat = {
                weaponDamage = 0.03,
                meleeDamage = 0.04
            }
        },
        triggers = {
            server = 'horizon_skill_tree:combat:unlocked',
            client = 'horizon_skill_tree:combat:unlockedClient'
        }
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

-- Integracje zewnętrzne (np. 0r-fishing v2 przez bridge serverowy)
Config.Integrations = Config.Integrations or {}
Config.Integrations.Fishing = {
    Enabled = true,
    Events = {
        CatchReportedServer = 'horizon_skill_tree:integration:fishing:catchReported'
    },
    XP = {
        BasePerCatch = 10,
        RarityBonus = {
            common = 0,
            uncommon = 3,
            rare = 8,
            epic = 15,
            legendary = 30
        },
        MaxPerCatch = 250
    },
    Security = {
        AllowedBridgeResources = { '0r-fishing', '0r-fishing-bridge' },
        RequireKnownRarity = true
    },
    Defaults = {
        xpMultiplier = 1.0,
        rareChanceMultiplier = 1.0
    },
    Limits = {
        MaxXPMultiplier = 3.0,
        MaxRareChanceMultiplier = 2.0
    }
}

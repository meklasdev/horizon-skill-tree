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
    MaxRecoilReduction = 0.35, -- max 35% mniej odrzutu
    ReapplyOnSpawn = true
}

-- Natywne modyfikatory gracza/pojazdu
Config.Native = {
    Movement = {
        Enabled = true,
        MaxSprintBonus = 0.05, -- bazowo 1.0, maks 1.05
        MaxStaminaBonus = 0.25 -- bazowo 1.0, maks 1.25
    },
    Underwater = {
        Enabled = true,
        BaseMaxTime = 10.0, -- domyślny czas pod wodą
        MaxTimeBonus = 25.0 -- dodatkowe sekundy z drzewka
    },
    Driving = {
        Enabled = true,
        MaxDamageReduction = 0.35 -- redukcja obrażeń pojazdu max 35%
    }
}

-- XP przyznawane automatycznie za aktywność
Config.ActivityXP = {
    Enabled = true,
    IntervalSeconds = 60,
    BasePlayXP = 6,
    AFK = {
        Enabled = true,
        MinDistance = 1.5,
        MaxIdleIntervals = 2
    },
    Running = {
        Enabled = true,
        MinSpeed = 2.8,
        BonusXP = 4
    },
    Driving = {
        Enabled = true,
        MinSpeed = 12.0,
        BonusXP = 6
    }
}

-- Jedna komenda administracyjna ESX:
-- /skilladmin <id|me> <addxp|addsp|reset> [amount]
Config.Admin = {
    Command = 'skilladmin',
    AllowedGroups = { 'admin', 'superadmin' }
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
    strength_1 = {
        id = 'strength_1',
        name = 'Siła',
        description = 'Podstawowe rozwinięcie siły.',
        cost = 1,
        requirement = nil,
        x = 48,
        y = 58,
        color = '#3a86ff',
        category = 'strength'
    },
    melee_1 = {
        id = 'melee_1',
        name = 'Rozwinięcie na wręcz',
        description = 'Większe obrażenia w walce wręcz.',
        cost = 2,
        requirement = 'strength_1',
        x = 62,
        y = 44,
        color = '#3a86ff',
        category = 'combat',
        effects = {
            combat = {
                meleeDamage = 0.06
            }
        }
    },
    recoil_1 = {
        id = 'recoil_1',
        name = 'Odrzut broni',
        description = 'Mniejszy odrzut podczas strzelania.',
        cost = 2,
        requirement = 'strength_1',
        x = 62,
        y = 70,
        color = '#5f6cff',
        category = 'combat',
        effects = {
            combat = {
                recoilReduction = 0.12
            }
        }
    },
    legs_1 = {
        id = 'legs_1',
        name = 'Nogi I',
        description = 'Szybsze bieganie (+1%) i większa stamina.',
        cost = 1,
        requirement = nil,
        x = 32,
        y = 58,
        color = '#f72585',
        category = 'movement',
        effects = {
            movement = {
                sprintBonus = 0.01,
                staminaBonus = 0.05
            }
        }
    },
    legs_2 = {
        id = 'legs_2',
        name = 'Nogi II',
        description = 'Szybsze bieganie (+2%) i większa stamina.',
        cost = 1,
        requirement = 'legs_1',
        x = 20,
        y = 48,
        color = '#f72585',
        category = 'movement',
        effects = {
            movement = {
                sprintBonus = 0.02,
                staminaBonus = 0.05
            }
        }
    },
    legs_3 = {
        id = 'legs_3',
        name = 'Nogi III',
        description = 'Szybsze bieganie (+3%) i większa stamina.',
        cost = 1,
        requirement = 'legs_2',
        x = 12,
        y = 36,
        color = '#f72585',
        category = 'movement',
        effects = {
            movement = {
                sprintBonus = 0.03,
                staminaBonus = 0.05
            }
        }
    },
    legs_4 = {
        id = 'legs_4',
        name = 'Nogi IV',
        description = 'Szybsze bieganie (+4%) i większa stamina.',
        cost = 1,
        requirement = 'legs_3',
        x = 20,
        y = 24,
        color = '#f72585',
        category = 'movement',
        effects = {
            movement = {
                sprintBonus = 0.04,
                staminaBonus = 0.05
            }
        }
    },
    legs_5 = {
        id = 'legs_5',
        name = 'Nogi V',
        description = 'Szybsze bieganie (+5%) i większa stamina.',
        cost = 1,
        requirement = 'legs_4',
        x = 28,
        y = 16,
        color = '#f72585',
        category = 'movement',
        effects = {
            movement = {
                sprintBonus = 0.05,
                staminaBonus = 0.05
            }
        }
    },
    lungs_1 = {
        id = 'lungs_1',
        name = 'Buzia I',
        description = 'Dłuższe oddychanie pod wodą.',
        cost = 1,
        requirement = nil,
        x = 68,
        y = 58,
        color = '#ffbe0b',
        category = 'underwater',
        effects = {
            underwater = {
                maxTimeBonus = 5.0
            }
        }
    },
    lungs_2 = {
        id = 'lungs_2',
        name = 'Buzia II',
        description = 'Jeszcze dłuższe oddychanie pod wodą.',
        cost = 1,
        requirement = 'lungs_1',
        x = 80,
        y = 48,
        color = '#ffbe0b',
        category = 'underwater',
        effects = {
            underwater = {
                maxTimeBonus = 5.0
            }
        }
    },
    lungs_3 = {
        id = 'lungs_3',
        name = 'Buzia III',
        description = 'Duża wytrzymałość pod wodą.',
        cost = 1,
        requirement = 'lungs_2',
        x = 88,
        y = 36,
        color = '#ffbe0b',
        category = 'underwater',
        effects = {
            underwater = {
                maxTimeBonus = 5.0
            }
        }
    },
    lungs_4 = {
        id = 'lungs_4',
        name = 'Buzia IV',
        description = 'Bardzo duża wytrzymałość pod wodą.',
        cost = 1,
        requirement = 'lungs_3',
        x = 80,
        y = 24,
        color = '#ffbe0b',
        category = 'underwater',
        effects = {
            underwater = {
                maxTimeBonus = 5.0
            }
        }
    },
    lungs_5 = {
        id = 'lungs_5',
        name = 'Buzia V',
        description = 'Maksymalna wytrzymałość pod wodą.',
        cost = 1,
        requirement = 'lungs_4',
        x = 70,
        y = 12,
        color = '#ffbe0b',
        category = 'underwater',
        effects = {
            underwater = {
                maxTimeBonus = 5.0
            }
        }
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

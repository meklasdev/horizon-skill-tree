# horizon-skill-tree

Fivem script ESX - skill tree z NUI.

## Instalacja
1. Umieść zasób w `resources/[local]/horizon-skill-tree`.
2. Dodaj `ensure horizon-skill-tree` do `server.cfg`.
3. Upewnij się, że masz uruchomione `oxmysql` i `es_extended`.

## Najważniejsze pliki
- `config.lua` - konfiguracja klawisza, komendy i całego drzewka.
- `server.lua` - logika XP/Level/Skill Points + zapisy do MySQL.
- `client.lua` - otwieranie/zamykanie NUI, blokada sterowania i obsługa callbacków.
- `web/*` - interfejs NUI.

## Nowe opcje konfiguracji
- `Config.Triggers`:
  - `OpenMenuClient` - event do otwierania/zamykania menu skilli.
  - `SyncCombatServer` - event żądania serwerowej synchronizacji bonusów walki.
  - `OnSkillUnlockServer` / `OnSkillUnlockClient` - globalne triggery po odblokowaniu skilla.
  - `OnLevelUpServer` - trigger po awansie poziomu.
- `Config.Combat`:
  - `Enabled` - włącza natywne modyfikatory walki.
  - `MaxWeaponBonus` / `MaxMeleeBonus` - limity anti-OP.
  - `ReapplyOnSpawn` - ponowna synchronizacja po respawnie.

## Jak rozszerzyć skilla o zależności i efekty
Każdy skill w `Config.Skills` może mieć dodatkowo:
- `effects` (np. `effects.combat.weaponDamage`, `effects.combat.meleeDamage`)
- `triggers` (`server`, `client`) odpalane po odblokowaniu konkretnego skilla.

## Domyślne sterowanie
- Komenda: `/skills`
- Klawisz: `K` (RegisterKeyMapping)

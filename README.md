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

## Integracja Fishing (0r-fishing v2 przez bridge)
- Skrypt nie zakłada sztywnych eventów 0r-fishing — używa konfigurowalnego bridge eventu:
  - `Config.Integrations.Fishing.Events.CatchReportedServer`
  - domyślnie: `horizon_skill_tree:integration:fishing:catchReported`
- Bridge powinien działać po stronie serwera i po złowieniu ryby wywołać:
  - `TriggerEvent('horizon_skill_tree:integration:fishing:catchReported', src, { rarity = 'rare', fish = 'salmon' })`
- Autoryzacja bridge zasobu odbywa się przez whitelistę:
  - `Config.Integrations.Fishing.Security.AllowedBridgeResources`
- Dostępne eksporty dla innych skryptów:
  - `exports['horizon-skill-tree']:GetFishingModifiers(source)` → `{ xpMultiplier, rareChanceMultiplier }`
  - `exports['horizon-skill-tree']:GetFishingXPForCatch(source, catchData)` → liczba XP za pojedynczy połów
  - `exports['horizon-skill-tree']:AwardFishingXP(source, catchData)` → nalicza XP i zapisuje progres
- `catchData.rarity` powinno odpowiadać kluczom z `Config.Integrations.Fishing.XP.RarityBonus`.
- Publiczne net eventy `addXP/addSkillPoints` są domyślnie zablokowane i można je świadomie odblokować przez `Config.Security`.

## Domyślne sterowanie
- Komenda: `/skills`
- Klawisz: `K` (RegisterKeyMapping)

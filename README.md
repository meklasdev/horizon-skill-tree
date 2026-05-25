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

## Domyślne sterowanie
- Komenda: `/skills`
- Klawisz: `K` (RegisterKeyMapping)

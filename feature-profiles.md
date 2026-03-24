# Feature: Profile — wiele kont Claude Code

## Motywacja

Deweloper może mieć kilka kont Claude Code jednocześnie — np. prywatne (Claude Pro) i firmowe (Team plan). Problem: Claude Code przechowuje konfigurację w `~/.claude/` i obsługuje tylko jedno aktywne konto naraz. Przełączanie przez `claude auth logout` / `claude auth login` jest wolne i uciążliwe, szczególnie gdy pracuje się nad prywatnymi i firmowymi projektami w tym samym czasie.

Claude Voice Bar już zarządza sesjami tmux z Claude — naturalnym rozszerzeniem jest żeby zarządzał też tym, *które konto* dana sesja używa.

## Cel

Użytkownik startuje sesję jedną komendą z nazwą profilu:

```bash
claude-vb             # profil domyślny (personal)
claude-vb work        # profil firmowy
```

Voice Bar widzi obie sesje naraz, oznacza je wizualnie i wysyła do właściwej — bez żadnego logowania/wylogowania.

## Jak to działa

Claude Code szuka konfiguracji w `$HOME/.claude/`. Jeśli uruchomimy `claude` z nadpisanym `HOME`, użyje innego katalogu konfiguracyjnego — a co za tym idzie, innego zalogowanego konta. Każdy profil to po prostu osobny katalog:

```
~/.claude/            ← konto prywatne (domyślne)
~/.claude-work/       ← konto firmowe (lub dowolna inna nazwa)
```

Każdy katalog zawiera własny stan autoryzacji (`claude auth login` wykonane w jego kontekście).

## Przepływ

```
claude-vb work
→ wrapper czyta ~/.claude-vb-profiles (name → HOME path)
→ "work" → HOME=/Users/marek/.claude-work
→ tmux new -s "work/myproject" -e HOME=... "claude"

Voice Bar wykrywa sesje tmux z claude
→ TmuxSessionManager parsuje prefix "work/" z nazwy sesji
→ SessionPopover wyświetla sesję z oznaczeniem profilu
→ głos trafia do właściwej sesji jak dotychczas
```

## Struktura zmian

### `~/.claude-vb-profiles` (nowy plik konfiguracyjny)

Prosty format `nazwa=ścieżka`:

```
personal=/Users/marek
work=/Users/marek/.claude-work
```

Tworzony przez `install.sh` przy konfiguracji profili. Użytkownik może edytować ręcznie.

### `claude-voice-bar-wrapper` (modyfikacja)

Przyjmuje opcjonalny argument — nazwę profilu:

```bash
claude-vb [profil]
```

- Czyta `~/.claude-vb-profiles`
- Mapuje nazwę profilu na HOME
- Tworzy sesję tmux z prefiksem `profil/nazwa-katalogu` i ustawionym `HOME`
- Brak argumentu → profil `personal` (domyślny)

### `TmuxSessionManager.swift` (modyfikacja)

Zamiast `[String]` zwraca `[ClaudeSession]`:

```swift
struct ClaudeSession {
    let name: String      // pełna nazwa sesji tmux, np. "work/myproject"
    let displayName: String  // "myproject"
    let profile: String?     // "work", nil jeśli personal
}
```

Parsowanie: jeśli nazwa zawiera `/`, część przed ukośnikiem to profil.

### `SessionPopoverView.swift` (modyfikacja)

Przy każdej sesji wyświetla oznaczenie profilu — np. badge z nazwą lub kolorowy wskaźnik:

```
  myproject
⬡ work / api-service
  hobby-app
```

## Setup (rozszerzenie install.sh)

Podczas instalacji skrypt pyta o profile:

```
Skonfiguruj profile Claude Code.
Profil domyślny (personal) → ~/.claude (obecna konfiguracja)

Dodać profil firmowy? [T/n]
Nazwa profilu: work
Katalog konfiguracyjny [~/.claude-work]:

→ Tworzę ~/.claude-work/
→ Uruchom: HOME=~/.claude-work claude auth login
   żeby zalogować się na konto firmowe.
```

## Uwagi techniczne

- `HOME` nadpisane przez `-e HOME=...` w `tmux new-session` zostaje w środowisku sesji przez cały jej czas życia — `claude` uruchamiane ponownie w tej samej sesji nadal używa właściwego konta
- Backward-compatible: sesje bez prefixu traktowane jak `personal`, stary `claude-vb` działa bez zmian
- Nazwa profilu w prefiksie nie może zawierać `/` — ograniczenie do sprawdzenia w wrapperze
- Jeśli `~/.claude-vb-profiles` nie istnieje, wrapper działa jak dotychczas (jedno konto)

## Do zrobienia

- [ ] Rozszerzenie `install.sh` o setup profili
- [ ] Modyfikacja `claude-voice-bar-wrapper`
- [ ] `ClaudeSession` struct w `TmuxSessionManager.swift`
- [ ] Oznaczenie profilu w `SessionPopoverView.swift`
- [ ] Obsługa edge case: profil z `~/.claude-vb-profiles` nie istnieje na dysku

# Aliucord Stratum (`40-apps/aliucord`)

Aliucord (Discord Android Client Mod) configuration, themes, and plugin definitions.

## Mobile to Desktop Parity
This stratum harmonizes with [`strata/40-apps/vencord`](../vencord/) to provide a consistent Discord experience across desktop and mobile:
- `NitroSpoof` ↔ `FakeNitro`
- `BetterSilentTyping` ↔ `SilentTyping`
- `CallTime` ↔ `CallTimer`
- `ReadAllButton` ↔ `ReadAllNotificationsButton`
- `ShowHiddenChannels` ↔ `ShowHiddenChannels`

## Files
- `Aliucord.json`: Core client preferences and plugin toggles.
- `rain.json`: Custom dark ambient theme (Dracula Dark base with DM Sans font).
- `settings/`: Specific plugin configuration payloads (`BetterSilentTyping`, `DedicatedPluginSettings`, `FolderOpacity`, `VoiceMessages`).
- `plugins.yaml`: Declarative inventory of installed Aliucord plugins.

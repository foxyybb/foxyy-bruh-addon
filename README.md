# Foxyy Bruh

A small addon targeting **World of Warcraft: Forever 1.60.1, Interface 16001**.
When another player sends an enabled word (case-insensitive, ignoring surrounding
whitespace), echo that word in lowercase in the same conversation. Starts with
`bruh` enabled.

## Installation

1. Download the repository using **Code > Download ZIP**, then extract it.
2. Rename the extracted folder to `foxyy_bruh` and copy it into your **Forever**
   installation's `Interface/AddOns` directory. The layout must be
   `Interface/AddOns/foxyy_bruh/foxyy_bruh.toc`, without an extra nested folder.
3. Fully quit and restart WoW so it discovers the addon, then enable
   **Foxyy Bruh** in the AddOns list.

To update, replace the files in the existing `foxyy_bruh` folder and use `/reload`.
You do not need to delete your saved settings. The README and `tests` folder are
not loaded by WoW and can be omitted from the installed copy.

## Settings

Use `/bruh` or **Settings > AddOns > Foxyy Bruh** to manage words, chats, and
individual joined public/custom channels. Settings are saved separately for
each character.

Under **Words to echo**, type a word and click **Add word** (or press Enter).
Use its **ON/OFF switch** to include or exclude it without losing it from the
list, or **Remove** to delete it. `bruh` can also be disabled or removed, and an
empty list stays empty after reload. Words must be single tokens without spaces,
control characters, or `|`, with a maximum length of 255 bytes. Duplicate words
are rejected case-insensitively. New words start enabled. Case conversion uses
Lua's lowercase handling; accented and other non-ASCII case variants are not
guaranteed to match.

Numbered public/custom channels are **off by default**; enable each desired
channel explicitly under **Joined channels**. Other supported chat types start
enabled. The **Enable automatic replies** switch controls the entire addon;
the **Public / custom channels** switch must also be on for numbered-channel
replies.

| Command | Action |
| --- | --- |
| `/bruh` | Open settings |
| `/bruh on` | Enable the addon |
| `/bruh off` | Disable the addon |
| `/bruh status` | Show whether the addon is enabled |

Each player who should reply needs the addon; the player sending the original
message does not. For example, with `bruh` enabled, another player's `BRUH`
produces a lowercase `bruh` reply in that same chat.

## Behavior and limits

- Supports guild, officer, party, raid, instance/battleground, say, yell, ordinary
  whispers, and numbered public/custom channels. Leader events use normal group
  chat, not raid warnings. A whisper is answered privately to its sender.
- Ignores your own messages. Does not listen to Battle.net whispers, communities,
  system messages, outgoing whisper notifications, or addon traffic.
- Replies at most once every **3 seconds per destination**, with separate cooldowns
  for individual whisper senders and numbered channels. Messages during cooldown
  are discarded; there is no delayed retry queue.
- Matches the entire message, not substrings: `hey bruh` does not match `bruh`,
  and `bruh!` matches only if explicitly added. Different words share the same
  per-destination cooldown.
- Numbered channels require a physical click to send. Say/yell also require a
  click outside instances. These display one **3-second send prompt**; subsequent
  prompt requests are ignored until it is sent, dismissed, or expires.
- Channel membership and settings are checked again before sending. A pending
  reply follows the same channel name if its number changes, never another
  channel that inherits its old number. New channel names default to disabled.
  Channel switches remain editable even when WoW marks the channel unavailable
  or the addon/public-chat master toggle is off. Changing a switch only changes
  the addon's preference; it does not join, unmute, or unlock the WoW channel.
  Explicit saved ON/OFF choices are preserved on update.
- Chat-security lockdown and secret chat payloads are skipped entirely: the addon
  cannot inspect protected text to decide whether it matches an enabled word.
- The addon does not bypass protected actions, account restrictions, server
  throttling, or chat moderation. A failed send is not retried automatically.
  The affected chat type uses manual prompts for the rest of the session if its
  sending API raises an error or WoW reports a blocked chat action. Some server
  rejections do not raise Lua errors.
- Cooldowns **do not guarantee loop prevention** between multiple addon users:
  delayed messages arriving after the cooldown can trigger another round.
  Disable a chat or `/bruh off` if echoes become disruptive.

## Troubleshooting

- **Addon not listed:** check the folder name and TOC path above, then fully
  restart WoW. Make sure you installed into the Forever client, not another edition.
- **No reply:** check the addon, word, chat, and channel switches. Your own messages
  are ignored, and messages during a destination's cooldown are discarded.
- **A send prompt appears:** click **Send reply** within three seconds. This is
  expected for numbered channels and outdoor say/yell; it is not an automatic send.
- **Channel switch is on but chat is unavailable:** the switch only controls the
  addon. WoW's channel membership, permissions, lockdown, and server restrictions
  still apply.

## Compatibility and development

Targets **Forever 1.60.1, Interface 16001**. Other WoW editions are not supported
or validated. There are no external addon dependencies. The implementation uses
the modern settings API and `C_ChatInfo.SendChatMessage`, with fallbacks when those
entry points are absent.

**Validation status:** the local tests cover addon logic and settings handlers
using mocked WoW APIs. Live-client UI, chat permissions, and protected-action
behavior remain unverified; passing those tests is not proof of in-game compatibility.

With Lua installed, run from the repository root:

```sh
lua tests/core_test.lua
luac -p Core.lua
luac -p Options.lua
luac -p tests/core_test.lua
```

Tests use mocked WoW APIs and do not send real chat. Test files are not loaded by
the addon.

For a live smoke test, use another player to check guild/group replies, private
whisper routing, public-channel prompts, outdoor say/yell prompts, cooldowns,
disabled words/channels, and settings after `/reload`. Also check channel
renumbering/leaving, two addon users echoing a trigger, and Lua/protected-action
errors during combat. Replies must never target an unrelated channel or make a
private whisper public.

API references:

- [Forever API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes)
- [Forever chat API source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
- [Chat restrictions](https://warcraft.wiki.gg/wiki/API_SendChatMessage)

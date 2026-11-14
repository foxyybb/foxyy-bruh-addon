local unpackValues = table.unpack or unpack
local tests = 0

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "Unexpected value") .. ": expected "
            .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function widget(parent)
    local object = { parent = parent, scripts = {}, events = {}, shown = true, enabled = true }
    function object:SetScript(name, callback)
        self.scripts[name] = callback
    end
    function object:RegisterEvent(name)
        self.events[name] = true
    end
    function object:SetText(text)
        assert(type(text) == "string")
        self.text = text
    end
    function object:GetText()
        return self.text or ""
    end
    function object:SetChecked(checked)
        self.checked = checked
    end
    function object:GetChecked()
        return self.checked
    end
    function object:SetEnabled(enabled)
        self.enabled = enabled
    end
    function object:IsEnabled()
        return self.enabled
    end
    function object:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end
    function object:Hide()
        self.shown = false
    end
    function object:SetShown(shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end
    function object:IsShown()
        return self.shown
    end
    function object:CreateFontString()
        return widget(self)
    end
    function object:CreateTexture()
        return widget(self)
    end
    function object:SetHeight(height)
        self.height = height
    end
    function object:SetScrollChild(child)
        self.scrollChild = child
    end
    for _, method in ipairs({
        "SetPoint", "SetSize", "SetWidth", "SetJustifyH", "SetFrameStrata",
        "SetClampedToScreen", "SetBackdrop", "ClearAllPoints", "SetColorTexture",
        "SetAlpha", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "SetTextColor",
        "SetWordWrap",
    }) do
        object[method] = function() end
    end
    return object
end

local function setup(saved, withOptions, legacy)
    local env = {
        time = 0, sent = {}, logs = {}, widgets = {}, channels = {},
        guild = true, party = true, raid = true, instanceGroup = true,
        instance = false, locked = false,
    }
    UIParent = widget()
    FoxyyBruhDB = saved
    SlashCmdList = {}
    LE_PARTY_CATEGORY_HOME = 1
    LE_PARTY_CATEGORY_INSTANCE = 2
    function CreateFrame(kind, name, parent, template)
        local frame = widget(parent)
        frame.kind, frame.name, frame.template = kind, name, template
        if kind == "CheckButton" then
            frame.Text = widget(frame)
        end
        env.widgets[#env.widgets + 1] = frame
        return frame
    end
    function GetTime()
        return env.time
    end
    function UnitGUID()
        return "Player-Self"
    end
    function UnitFullName()
        return "Me", "HomeRealm"
    end
    UnitName = UnitFullName
    function GetNormalizedRealmName()
        return "HomeRealm"
    end
    GetRealmName = GetNormalizedRealmName
    function IsInGuild()
        return env.guild
    end
    function IsInGroup(category)
        if category == LE_PARTY_CATEGORY_INSTANCE then
            return env.instanceGroup
        end
        return env.party
    end
    function IsInRaid()
        return env.raid
    end
    function IsInInstance()
        return env.instance
    end
    function GetChannelList()
        return unpackValues(env.channels)
    end
    local secret = {}
    env.secret = secret
    function issecretvalue(value)
        return value == secret
    end
    local function send(message, chatType, language, target)
        if env.reentrant then
            local callback = env.reentrant
            env.reentrant = nil
            callback()
        end
        if env.fail then
            error("Simulated rejection")
        end
        if env.block then
            env.fire("ADDON_ACTION_BLOCKED", "foxyy_bruh", "C_ChatInfo.SendChatMessage()")
            return
        end
        env.sent[#env.sent + 1] = {
            message = message, chatType = chatType, language = language, target = target,
        }
    end
    SendChatMessage = legacy and send or nil
    C_ChatInfo = {
        SendChatMessage = not legacy and send or nil,
        InChatMessagingLockdown = function()
            return env.locked
        end,
    }
    DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, text)
            env.logs[#env.logs + 1] = text
        end,
    }
    Settings = not legacy and {
        RegisterCanvasLayoutCategory = function(panel, name)
            env.registeredPanel = panel
            equal(name, "Foxyy Bruh")
            return { GetID = function() return 42 end }
        end,
        RegisterAddOnCategory = function(category)
            equal(category:GetID(), 42)
        end,
        OpenToCategory = function(id)
            env.openedCategory = id
        end,
    } or nil
    local addon = {}
    assert(loadfile("Core.lua"))("foxyy_bruh", addon)
    if withOptions then
        assert(loadfile("Options.lua"))("foxyy_bruh", addon)
    else
        function addon:ShowPrompt(destination, word)
            env.prompt = destination
            env.promptWord = word
        end
        function addon:HidePrompt()
            env.prompt = nil
        end
    end
    env.addon = addon
    function env.fire(event, ...)
        addon.frame.scripts.OnEvent(addon.frame, event, ...)
    end
    function env.chat(event, message, sender, guid, id, name)
        env.fire(event, message, sender or "Other-HomeRealm", "Common", "",
            "", "", 0, id or 0, name or "", 0, 1, guid)
    end
    env.fire("ADDON_LOADED", "foxyy_bruh")
    env.fire("PLAYER_LOGIN")
    return env, addon
end

local function test(name, callback)
    local ok, failure = pcall(callback)
    if not ok then
        io.stderr:write("FAIL: " .. name .. "\n" .. tostring(failure) .. "\n")
        os.exit(1)
    end
    tests = tests + 1
    print("PASS: " .. name)
end

test("exact matching and normalized lowercase response", function()
    local e = setup()
    for _, message in ipairs({ "bruh!", "hey bruh", "bruh bruh", "bruhh", "", "bro" }) do
        e.chat("CHAT_MSG_GUILD", message)
    end
    equal(#e.sent, 0)
    e.chat("CHAT_MSG_GUILD", " \tBRuH \n")
    equal(#e.sent, 1)
    equal(e.sent[1].message, "bruh")
    equal(e.sent[1].chatType, "GUILD")
end)

test("self GUID and realm-aware name fallback", function()
    local e = setup()
    e.chat("CHAT_MSG_GUILD", "bruh", "Me-HomeRealm", "Player-Self")
    e.chat("CHAT_MSG_GUILD", "bruh", "Me")
    e.chat("CHAT_MSG_GUILD", "bruh", "Me-HomeRealm", "")
    equal(#e.sent, 0)
    e.chat("CHAT_MSG_GUILD", "bruh", "Me-OtherRealm")
    equal(#e.sent, 1)
end)

test("leader events normalize and cooldowns are per destination", function()
    local e = setup()
    e.chat("CHAT_MSG_PARTY_LEADER", "bruh")
    e.chat("CHAT_MSG_PARTY", "bruh")
    e.chat("CHAT_MSG_RAID_LEADER", "bruh")
    e.chat("CHAT_MSG_INSTANCE_CHAT_LEADER", "bruh")
    e.chat("CHAT_MSG_OFFICER", "bruh")
    equal(#e.sent, 4)
    equal(e.sent[1].chatType, "PARTY")
    equal(e.sent[2].chatType, "RAID")
    equal(e.sent[3].chatType, "INSTANCE_CHAT")
    e.time = 2.999
    e.chat("CHAT_MSG_PARTY", "bruh")
    equal(#e.sent, 4)
    e.time = 3
    e.chat("CHAT_MSG_PARTY", "bruh")
    equal(#e.sent, 5)
end)

test("whispers remain private and have independent sender cooldowns", function()
    local e = setup()
    e.chat("CHAT_MSG_WHISPER", "bruh", "Alice-Elsewhere")
    e.chat("CHAT_MSG_WHISPER", "bruh", "Alice-Elsewhere")
    e.chat("CHAT_MSG_WHISPER", "bruh", "Bob-Elsewhere")
    equal(#e.sent, 2)
    equal(e.sent[1].chatType, "WHISPER")
    equal(e.sent[1].target, "Alice-Elsewhere")
    equal(e.sent[2].target, "Bob-Elsewhere")
    e.chat("CHAT_MSG_WHISPER_INFORM", "bruh", "Alice-Elsewhere")
    e.chat("CHAT_MSG_BN_WHISPER", "bruh")
    e.chat("CHAT_MSG_COMMUNITIES_CHANNEL", "bruh")
    e.chat("CHAT_MSG_ADDON", "bruh")
    e.chat("CHAT_MSG_SYSTEM", "bruh")
    equal(#e.sent, 2)
end)

test("settings preserve explicit choices and drop disabled triggers", function()
    local e, a = setup({
        enabled = false, chats = { GUILD = false }, channels = { trade = false },
    })
    equal(a.db.enabled, false)
    equal(a.db.chats.GUILD, false)
    equal(a.db.chats.PARTY, true)
    equal(a.db.channels.trade, false)
    e.chat("CHAT_MSG_PARTY", "bruh")
    equal(#e.sent, 0)
    a.db.enabled = true
    e.chat("CHAT_MSG_GUILD", "bruh")
    e.chat("CHAT_MSG_PARTY", "bruh")
    equal(#e.sent, 1)
    SlashCmdList.FOXYYBRUH("off")
    equal(a.db.enabled, false)
    SlashCmdList.FOXYYBRUH("on")
    equal(a.db.enabled, true)
end)

test("pending prompts keep the first trigger, expire, and never retry", function()
    local e, a = setup()
    e.chat("CHAT_MSG_SAY", "bruh")
    equal(#e.sent, 0)
    equal(e.prompt, "SAY")
    e.chat("CHAT_MSG_YELL", "bruh")
    equal(e.prompt, "SAY")
    e.time = 3
    equal(a:SendPending(), false)
    equal(e.prompt, nil)
    equal(#e.sent, 0)
    e.chat("CHAT_MSG_YELL", "bruh")
    equal(e.prompt, "YELL")
    equal(a:SendPending(), true)
    equal(#e.sent, 1)
    equal(e.sent[1].chatType, "YELL")
    e.time = 4
    e.chat("CHAT_MSG_YELL", "bruh")
    equal(e.prompt, nil)
    e.time = 6
    e.chat("CHAT_MSG_YELL", "bruh")
    equal(e.prompt, "YELL")
    a:ClearPending()
    equal(a:SendPending(), false)
end)

test("say/yell automate only inside an instance", function()
    local e = setup()
    e.instance = true
    e.chat("CHAT_MSG_SAY", "bruh")
    e.chat("CHAT_MSG_YELL", "bruh")
    equal(#e.sent, 2)
    equal(e.prompt, nil)
end)

test("channel renumbering keeps identity and per-channel cooldowns", function()
    local e, a = setup({ channels = { general = true, trade = true } })
    e.channels = { 1, "General", false, 2, "Trade", false }
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 1, "General")
    equal(#e.sent, 0)
    e.channels = { 1, "Trade", false, 5, "General", false }
    equal(a:SendPending(), true)
    equal(e.sent[1].target, "5")
    equal(e.sent[1].chatType, "CHANNEL")
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 5, "General")
    equal(e.prompt, nil)
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 1, "Trade")
    equal(e.prompt, "Trade")
    a:SendPending()
    equal(e.sent[2].target, "1")
    e.time = 3
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 5, "General")
    equal(e.prompt, "General")
end)

test("disabled, mismatched, or departed channels cannot send", function()
    local e, a = setup({ channels = { general = true, trade = false, localdefense = true } })
    e.channels = { 1, "General", false, 2, "Trade", false, 3, "LocalDefense", true }
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 1, "Trade")
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 2, "Trade")
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 3, "LocalDefense")
    equal(e.prompt, nil)
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 1, "General")
    e.channels = { 1, "Unrelated", false }
    equal(a:SendPending(), false)
    equal(#e.sent, 0)
end)

test("settings and world changes invalidate pending prompts", function()
    local e, a = setup()
    e.chat("CHAT_MSG_SAY", "bruh")
    a.db.chats.SAY = false
    a:SettingsChanged()
    equal(e.prompt, nil)
    equal(a:SendPending(), false)
    a.db.chats.SAY = true
    e.chat("CHAT_MSG_SAY", "bruh")
    e.fire("PLAYER_ENTERING_WORLD")
    equal(e.prompt, nil)
    e.chat("CHAT_MSG_SAY", "bruh")
    SlashCmdList.FOXYYBRUH("off")
    equal(e.prompt, nil)
end)

test("membership changes prevent group sends", function()
    local e = setup()
    e.guild, e.party, e.raid, e.instanceGroup = false, false, false, false
    for _, event in ipairs({
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
        "CHAT_MSG_RAID", "CHAT_MSG_INSTANCE_CHAT",
    }) do
        e.chat(event, "bruh")
    end
    equal(#e.sent, 0)
end)

test("lockdown and secret payloads are never inspected or echoed", function()
    local e, a = setup()
    e.locked = true
    e.chat("CHAT_MSG_GUILD", "bruh")
    e.locked = false
    e.chat("CHAT_MSG_GUILD", e.secret)
    e.chat("CHAT_MSG_GUILD", "bruh", e.secret)
    e.chat("CHAT_MSG_GUILD", "bruh", nil, e.secret)
    equal(#e.sent, 0)
    e.chat("CHAT_MSG_SAY", "bruh")
    e.locked = true
    equal(a:SendPending(), false)
    equal(e.prompt, nil)
end)

test("synchronous events cannot reenter the same destination", function()
    local e = setup()
    e.reentrant = function()
        e.chat("CHAT_MSG_GUILD", "bruh")
    end
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.sent, 1)
end)

test("failed sends switch to manual without automatic retries", function()
    local e, a = setup()
    e.fail = true
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.logs, 1)
    equal(#e.sent, 0)
    e.time = 3
    e.fail = false
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(e.prompt, "GUILD")
    equal(#e.sent, 0)
    equal(a:SendPending(), true)
    equal(#e.sent, 1)
end)

test("protected-action events switch subsequent sends to manual", function()
    local e, a = setup()
    e.block = true
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.sent, 0)
    equal(#e.logs, 1)
    e.time = 3
    e.block = false
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(e.prompt, "GUILD")
    a:SendPending()
    equal(#e.sent, 1)
end)

test("settings UI toggles, channel refresh, and real button handler", function()
    local e, a = setup({ channels = { general = true, trade = true } }, true)
    SlashCmdList.FOXYYBRUH("")
    equal(e.openedCategory, 42)
    e.channels = { 1, "General", false, 2, "Trade", false }
    e.fire("CHANNEL_UI_UPDATE")
    local trade = a.channelButtons[2]
    trade:SetChecked(false)
    trade.scripts.OnClick(trade)
    equal(a.db.channels.trade, false)
    e.channels = { 1, "Trade", false, 2, "General", false }
    e.fire("CHANNEL_UI_UPDATE")
    equal(a.channelButtons[1].checked, false)
    equal(a.channelButtons[2].checked, true)
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 2, "General")
    equal(a.prompt:IsShown(), true)
    a.promptSend.scripts.OnClick(a.promptSend)
    equal(a.prompt:IsShown(), false)
    equal(e.sent[1].target, "2")
    a.master:SetChecked(false)
    a.master.scripts.OnClick(a.master)
    equal(a.db.enabled, false)
    equal(a.chatButtons.GUILD.enabled, false)
end)

test("UI expiry clears prompt without a chat event", function()
    local e, a = setup(nil, true)
    e.chat("CHAT_MSG_SAY", "bruh")
    e.time = 3
    a.prompt.scripts.OnUpdate(a.prompt, 0.1)
    equal(a.prompt:IsShown(), false)
    equal(a.pending, nil)
    equal(#e.sent, 0)
end)

test("legacy send and standalone settings fallback", function()
    local e, a = setup(nil, true, true)
    SlashCmdList.FOXYYBRUH("")
    equal(a.panel:IsShown(), true)
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.sent, 1)
    SlashCmdList.FOXYYBRUH("")
    equal(a.panel:IsShown(), false)
end)

test("custom words match exactly, echo themselves, and share cooldowns", function()
    local e, a = setup()
    equal(a:AddWord("  LoL  "), true)
    e.chat("CHAT_MSG_GUILD", "hey lol")
    e.chat("CHAT_MSG_GUILD", "lol!")
    equal(#e.sent, 0)
    e.chat("CHAT_MSG_GUILD", " LOL ")
    equal(e.sent[1].message, "lol")
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.sent, 1)
    e.time = 3
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(e.sent[2].message, "bruh")
end)

test("word validation rejects blanks, multiple words, controls, escapes and duplicates", function()
    local _, a = setup()
    for _, word in ipairs({ "", "  ", "two words", "a\nb", "a\001b", "|cff00ff00hi", string.rep("a", 256) }) do
        local ok, message = a:AddWord(word)
        equal(ok, false)
        assert(message)
    end
    a.db.words.bruh = false
    equal(a:AddWord(" BRUH "), false)
    equal(a.db.words.bruh, false)
    equal(a:AddWord("bruh!"), true)
end)

test("existing saves gain bruh but disabled or removed words stay that way", function()
    local _, migrated = setup({ enabled = false, chats = { GUILD = false } })
    equal(migrated.db.words.bruh, true)
    equal(migrated.db.enabled, false)
    equal(migrated.db.chats.GUILD, false)
    local e, a = setup({ words = { bruh = false, lol = true } })
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.sent, 0)
    a:RemoveWord("bruh")
    local saved = a.db
    local reloaded, restored = setup(saved)
    equal(restored.db.words.bruh, nil)
    reloaded.chat("CHAT_MSG_GUILD", "bruh")
    reloaded.chat("CHAT_MSG_GUILD", "lol")
    equal(#reloaded.sent, 1)
    equal(reloaded.sent[1].message, "lol")
    restored:RemoveWord("lol")
    local empty, emptyAddon = setup(restored.db)
    equal(#emptyAddon:GetWords(), 0)
    empty.chat("CHAT_MSG_GUILD", "bruh")
    equal(#empty.sent, 0)
end)

test("restricted prompts send the matched word and invalidate disabled or removed words", function()
    local e, a = setup()
    a:AddWord("lol")
    e.chat("CHAT_MSG_SAY", "LOL")
    equal(e.promptWord, "lol")
    a:SendPending()
    equal(e.sent[1].message, "lol")
    e.time = 3
    e.chat("CHAT_MSG_SAY", "lol")
    a.db.words.lol = false
    a:SettingsChanged()
    equal(a.pending, nil)
    equal(a:SendPending(), false)
    a.db.words.lol = true
    e.chat("CHAT_MSG_SAY", "lol")
    a:RemoveWord("lol")
    equal(a.pending, nil)
    equal(a:SendPending(), false)
    equal(#e.sent, 1)
end)

test("word UI adds, switches and removes rows including bruh", function()
    local e, a = setup(nil, true)
    a.wordInput:SetText(" LoL ")
    a.addWordButton.scripts.OnClick(a.addWordButton)
    equal(a.db.words.lol, true)
    equal(a.wordInput:GetText(), "")
    equal(a.wordRows[1].word, "bruh")
    local bruhSwitch = a.wordRows[1].toggle
    bruhSwitch:SetChecked(false)
    bruhSwitch.scripts.OnClick(bruhSwitch)
    e.chat("CHAT_MSG_GUILD", "bruh")
    equal(#e.sent, 0)
    a.wordInput:SetText("BRUH")
    a.wordInput.scripts.OnEnterPressed(a.wordInput)
    assert(a.wordError:GetText() ~= "")
    equal(a.db.words.bruh, false)
    a.wordRows[1].remove.scripts.OnClick(a.wordRows[1].remove)
    equal(a.db.words.bruh, nil)
    equal(a.wordRows[1].word, "lol")
    local lolSwitch = a.wordRows[1].toggle
    lolSwitch:SetChecked(false)
    lolSwitch.scripts.OnClick(lolSwitch)
    equal(a.db.words.lol, false)
    lolSwitch:SetChecked(true)
    lolSwitch.scripts.OnClick(lolSwitch)
    e.chat("CHAT_MSG_WHISPER", "LOL", "Alice-Elsewhere")
    equal(e.sent[1].message, "lol")
    equal(e.sent[1].target, "Alice-Elsewhere")
    a.wordRows[1].remove.scripts.OnClick(a.wordRows[1].remove)
    equal(a.emptyWords:IsShown(), true)
    equal(a.wordRows[1].toggle:IsShown(), false)
    a.wordInput:SetText("bruh")
    a.wordInput.scripts.OnEnterPressed(a.wordInput)
    equal(a.db.words.bruh, true)
    equal(a.emptyWords:IsShown(), false)
end)

test("numbered channels default off, including channels 2, 4 and 5", function()
    local e, a = setup(nil, true)
    e.channels = { 2, "Trade", false, 4, "Services", false, 5, "LookingForGroup", false }
    e.fire("CHANNEL_UI_UPDATE")
    for index, name in ipairs({ "Trade", "Services", "LookingForGroup" }) do
        local id = e.channels[(index - 1) * 3 + 1]
        equal(a.channelButtons[index]:GetChecked(), false)
        e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, id, name)
        equal(a.pending, nil)
    end
    equal(#e.sent, 0)
    local trade = a.channelButtons[1]
    assert(trade:IsEnabled())
    trade:SetChecked(true)
    trade.scripts.OnClick(trade)
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 2, "Trade")
    assert(a.pending)
    trade:SetChecked(false)
    trade.scripts.OnClick(trade)
    equal(a.pending, nil)
    equal(a.db.channels.trade, false)
end)

test("unavailable channels can be switched off even with parent controls disabled", function()
    local e, a = setup({
        enabled = false,
        chats = { CHANNEL = false },
        channels = { trade = true, services = true, lookingforgroup = true },
    }, true)
    e.channels = { 2, "Trade", true, 4, "Services", true, 5, "LookingForGroup", true }
    e.fire("CHANNEL_UI_UPDATE")
    for _, button in ipairs(a.channelButtons) do
        equal(button:GetChecked(), true)
        assert(button:IsEnabled())
        button:SetChecked(false)
        button.scripts.OnClick(button)
        equal(a.db.channels[button.channelKey], false)
        equal(button:GetChecked(), false)
    end
    local saved = a.db
    local reloaded, restored = setup(saved, true)
    reloaded.channels = { 1, "Trade", false, 5, "Services", false, 2, "LookingForGroup", false }
    reloaded.fire("CHANNEL_UI_UPDATE")
    for _, button in ipairs(restored.channelButtons) do
        equal(button:GetChecked(), false)
    end
end)

test("editing unavailable channels does not bypass send availability", function()
    local e, a = setup(nil, true)
    e.channels = { 2, "Trade", true }
    e.fire("CHANNEL_UI_UPDATE")
    local trade = a.channelButtons[1]
    assert(trade:IsEnabled())
    trade:SetChecked(true)
    trade.scripts.OnClick(trade)
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 2, "Trade")
    equal(a.pending, nil)
    e.channels = { 2, "Trade", false }
    e.chat("CHAT_MSG_CHANNEL", "bruh", nil, nil, 2, "Trade")
    assert(a.pending)
end)

print(string.format("%d tests passed", tests))

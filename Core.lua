local addonName, Bruh = ...

Bruh.chatTypes = {
    { "GUILD", "Guild" },
    { "OFFICER", "Officer" },
    { "PARTY", "Party" },
    { "RAID", "Raid" },
    { "INSTANCE_CHAT", "Instance / battleground" },
    { "SAY", "Say" },
    { "YELL", "Yell" },
    { "WHISPER", "Whispers" },
    { "CHANNEL", "Public / custom channels" },
}

local eventTypes = {
    CHAT_MSG_GUILD = "GUILD",
    CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
    CHAT_MSG_WHISPER = "WHISPER",
    CHAT_MSG_CHANNEL = "CHANNEL",
}

local cooldowns = {}
local manualOnly = {}
local ready = false
local lastAttempt
local COOLDOWN = 3

local function isSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function channelKey(name)
    return name:lower()
end

local function chatLocked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
        and C_ChatInfo.InChatMessagingLockdown()
end

local function fullName(name, realm)
    if not name or name == "" then
        return nil
    end
    if not name:find("-", 1, true) then
        realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName())
            or GetRealmName()
        name = name .. "-" .. realm:gsub("%s+", "")
    end
    return name:lower()
end

local function isSelf(sender, guid)
    local playerGUID = UnitGUID("player")
    if guid and guid ~= "" and playerGUID then
        return guid == playerGUID
    end
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    else
        name, realm = UnitName("player")
    end
    return fullName(sender) == fullName(name, realm)
end

function Bruh:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc080ffFoxyy Bruh:|r " .. message)
    end
end

function Bruh:GetChannels()
    local result = {}
    if GetChannelList then
        local channels = { GetChannelList() }
        for i = 1, #channels, 3 do
            local id, name, disabled = channels[i], channels[i + 1], channels[i + 2]
            if type(id) == "number" and id > 0 and type(name) == "string" then
                result[#result + 1] = {
                    id = id,
                    name = name,
                    key = channelKey(name),
                    disabled = disabled,
                }
            end
        end
    end
    return result
end

function Bruh:NormalizeWord(value)
    if type(value) ~= "string" then
        return nil
    end
    local word = value:match("^%s*(.-)%s*$"):lower()
    if word == "" or #word > 255 or word:find("[%s%c|]") then
        return nil
    end
    return word
end

function Bruh:GetWords()
    local words = {}
    for word in pairs(self.db.words) do
        words[#words + 1] = word
    end
    table.sort(words)
    return words
end

function Bruh:AddWord(value)
    local word = self:NormalizeWord(value)
    if not word then
        return false, "Enter one word (up to 255 bytes), without spaces or |."
    end
    if self.db.words[word] ~= nil then
        return false, "That word is already listed. Use its switch to enable it."
    end
    self.db.words[word] = true
    self:SettingsChanged()
    return true
end

function Bruh:RemoveWord(word)
    self.db.words[word] = nil
    self:SettingsChanged()
end

function Bruh:Initialize()
    if type(FoxyyBruhDB) ~= "table" then
        FoxyyBruhDB = {}
    end
    self.db = FoxyyBruhDB
    if type(self.db.enabled) ~= "boolean" then
        self.db.enabled = true
    end
    if type(self.db.chats) ~= "table" then
        self.db.chats = {}
    end
    if type(self.db.channels) ~= "table" then
        self.db.channels = {}
    end
    if type(self.db.words) ~= "table" then
        self.db.words = { bruh = true }
    end
    for _, entry in ipairs(self.chatTypes) do
        if type(self.db.chats[entry[1]]) ~= "boolean" then
            self.db.chats[entry[1]] = true
        end
    end
end

function Bruh:ClearPending()
    self.pending = nil
    if self.HidePrompt then
        self:HidePrompt()
    end
end

function Bruh:DestinationAvailable(destination)
    if chatLocked() or not self.db or not self.db.enabled
        or not self.db.chats[destination.chatType] then
        return false
    end
    local chatType = destination.chatType
    if chatType == "CHANNEL" then
        if self.db.channels[destination.channelKey] ~= true then
            return false
        end
        for _, channel in ipairs(self:GetChannels()) do
            if channel.key == destination.channelKey and not channel.disabled then
                destination.target = channel.id
                return true
            end
        end
        return false
    elseif chatType == "GUILD" or chatType == "OFFICER" then
        return IsInGuild and IsInGuild()
    elseif chatType == "PARTY" then
        return IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME)
    elseif chatType == "RAID" then
        return IsInRaid and IsInRaid(LE_PARTY_CATEGORY_HOME)
    elseif chatType == "INSTANCE_CHAT" then
        return IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    end
    return true
end

function Bruh:OnCooldown(destination)
    local last = cooldowns[destination.key]
    return last ~= nil and GetTime() - last < COOLDOWN
end

function Bruh:ValidatePending()
    local pending = self.pending
    if pending and (GetTime() >= pending.expires
        or self.db.words[pending.word] ~= true
        or not self:DestinationAvailable(pending.destination)
        or self:OnCooldown(pending.destination)) then
        self:ClearPending()
    end
    return self.pending
end

function Bruh:SettingsChanged()
    self:ValidatePending()
    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

function Bruh:RequiresClick(destination)
    if manualOnly[destination.chatType] or destination.chatType == "CHANNEL" then
        return true
    end
    if destination.chatType == "SAY" or destination.chatType == "YELL" then
        return not IsInInstance or not IsInInstance()
    end
    return false
end

function Bruh:Send(destination, word)
    if self.db.words[word] ~= true
        or not self:DestinationAvailable(destination) or self:OnCooldown(destination) then
        return false
    end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then
        self:Print("Chat sending is unavailable in this client.")
        return false
    end
    -- Reserve before sending: chat events can be dispatched synchronously.
    cooldowns[destination.key] = GetTime()
    local target = destination.target
    if destination.chatType == "CHANNEL" then
        target = tostring(target)
    end
    local attempt = { chatType = destination.chatType }
    lastAttempt = attempt
    local ok = pcall(send, word, destination.chatType, nil, target)
    if not ok and not attempt.blocked then
        manualOnly[destination.chatType] = true
        self:Print("Send failed. Future " .. destination.chatType
            .. " replies require a click; no automatic retry was queued.")
    end
    return ok and not attempt.blocked
end

function Bruh:SendPending()
    local pending = self:ValidatePending()
    if not pending then
        return false
    end
    self:ClearPending()
    return self:Send(pending.destination, pending.word)
end

function Bruh:HandleChat(event, ...)
    if not ready or chatLocked() then
        return
    end
    local chatType = eventTypes[event]
    if not chatType then
        return
    end
    local message, sender = ...
    local guid = select(12, ...)
    if isSecret(message) or isSecret(sender) or isSecret(guid) then
        return
    end
    if type(message) ~= "string" or type(sender) ~= "string" or sender == "" then
        return
    end
    local word = self:NormalizeWord(message)
    if not word or self.db.words[word] ~= true or isSelf(sender, guid) then
        return
    end
    local destination = { chatType = chatType, key = chatType, label = chatType }
    if chatType == "WHISPER" then
        destination.target = sender
        destination.key = "WHISPER:" .. fullName(sender)
        destination.label = "Whisper to " .. sender
    elseif chatType == "CHANNEL" then
        local id, name = select(8, ...), select(9, ...)
        if isSecret(id) or isSecret(name) or type(name) ~= "string" then
            return
        end
        for _, channel in ipairs(self:GetChannels()) do
            if channel.id == id and channel.key == channelKey(name) then
                destination.channelKey = channel.key
                destination.target = channel.id
                destination.key = "CHANNEL:" .. channel.key
                destination.label = channel.name
                break
            end
        end
        if not destination.channelKey then
            return
        end
    end
    if not self:DestinationAvailable(destination) or self:OnCooldown(destination) then
        return
    end
    if self:RequiresClick(destination) then
        if self:ValidatePending() then
            return
        end
        self.pending = { destination = destination, word = word, expires = GetTime() + COOLDOWN }
        if self.ShowPrompt then
            self:ShowPrompt(destination.label, word)
        end
    else
        self:Send(destination, word)
    end
end

local frame = CreateFrame("Frame")
Bruh.frame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHANNEL_UI_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then
            Bruh:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        if not Bruh.db then
            Bruh:Initialize()
        end
        ready = true
        for chatEvent in pairs(eventTypes) do
            frame:RegisterEvent(chatEvent)
        end
        if Bruh.CreateOptions then
            Bruh:CreateOptions()
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local source, action = ...
        if source == addonName and type(action) == "string"
            and action:find("SendChatMessage", 1, true) and lastAttempt then
            lastAttempt.blocked = true
            manualOnly[lastAttempt.chatType] = true
            Bruh:Print("The client blocked chat sending. Future "
                .. lastAttempt.chatType .. " replies require a click.")
        end
    elseif eventTypes[event] then
        Bruh:HandleChat(event, ...)
    elseif Bruh.db then
        if event == "PLAYER_ENTERING_WORLD" then
            Bruh:ClearPending()
        end
        Bruh:SettingsChanged()
    end
end)

SLASH_FOXYYBRUH1 = "/bruh"
SlashCmdList.FOXYYBRUH = function(command)
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if not Bruh.db then
        return
    end
    if command == "on" or command == "off" then
        Bruh.db.enabled = command == "on"
        Bruh:SettingsChanged()
        Bruh:Print(command == "on" and "Enabled." or "Disabled.")
    elseif command == "status" then
        Bruh:Print((Bruh.db.enabled and "Enabled" or "Disabled")
            .. "; 3-second cooldown per destination. /bruh opens settings.")
    elseif Bruh.OpenOptions then
        Bruh:OpenOptions()
    end
end

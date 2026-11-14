local _, Bruh = ...

local function label(parent, text, x, y, font)
    local result = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    result:SetPoint("TOPLEFT", x, y)
    result:SetText(text)
    return result
end

local function toggle(parent, text, x, y, callback)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(410, 24)
    button:SetPoint("TOPLEFT", x, y)
    local track = button:CreateTexture(nil, "BACKGROUND")
    track:SetSize(36, 18)
    track:SetPoint("LEFT")
    local thumb = button:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(14, 14)
    thumb:SetColorTexture(1, 1, 1)
    local state = label(button, "", 44, -6, "GameFontHighlightSmall")
    button.Text = label(button, "", 74, -4)
    button.Text:SetWidth(330)
    button.Text:SetHeight(20)
    button.Text:SetWordWrap(false)
    button.Text:SetJustifyH("LEFT")
    button.Text:SetText(text)
    local function refresh()
        local checked = button:GetChecked()
        if checked then
            track:SetColorTexture(0.12, 0.55, 0.3)
        else
            track:SetColorTexture(0.25, 0.25, 0.28)
        end
        thumb:ClearAllPoints()
        thumb:SetPoint(checked and "RIGHT" or "LEFT", track,
            checked and "RIGHT" or "LEFT", checked and -2 or 2, 0)
        state:SetText(checked and "ON" or "OFF")
        button:SetAlpha(button:IsEnabled() and 1 or 0.45)
    end
    local setChecked, setEnabled = button.SetChecked, button.SetEnabled
    function button:SetChecked(checked)
        setChecked(self, checked)
        refresh()
    end
    function button:SetEnabled(enabled)
        setEnabled(self, enabled)
        refresh()
    end
    button:SetScript("OnClick", function(self)
        callback(self:GetChecked())
        Bruh:SettingsChanged()
    end)
    refresh()
    return button
end

function Bruh:RefreshOptions()
    if not self.panel then
        return
    end
    self.master:SetChecked(self.db.enabled)
    local words = self:GetWords()
    for index, word in ipairs(words) do
        local row = self.wordRows[index]
        if not row then
            row = {}
            row.toggle = toggle(self.content, "", 12, 0, function(checked)
                self.db.words[row.word] = checked
            end)
            row.remove = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
            row.remove:SetSize(80, 24)
            row.remove:SetText("Remove")
            row.remove:SetScript("OnClick", function()
                self:RemoveWord(row.word)
            end)
            self.wordRows[index] = row
        end
        row.word = word
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("TOPLEFT", 12, -150 - (index - 1) * 30)
        row.toggle.Text:SetText(word)
        row.toggle:SetChecked(self.db.words[word] == true)
        row.toggle:Show()
        row.remove:ClearAllPoints()
        row.remove:SetPoint("TOPLEFT", 440, -150 - (index - 1) * 30)
        row.remove:Show()
    end
    for index = #words + 1, #self.wordRows do
        self.wordRows[index].toggle:Hide()
        self.wordRows[index].remove:Hide()
    end
    self.emptyWords:SetShown(#words == 0)
    local chatY = -168 - math.max(1, #words) * 30
    self.chatHeading:ClearAllPoints()
    self.chatHeading:SetPoint("TOPLEFT", 16, chatY)
    for index, entry in ipairs(self.chatTypes) do
        local button = self.chatButtons[entry[1]]
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 12, chatY - 26 - (index - 1) * 30)
        button:SetChecked(self.db.chats[entry[1]])
        button:SetEnabled(self.db.enabled)
    end
    local channelY = chatY - 42 - #self.chatTypes * 30
    self.channelHeading:ClearAllPoints()
    self.channelHeading:SetPoint("TOPLEFT", 16, channelY)
    self.channelHint:ClearAllPoints()
    self.channelHint:SetPoint("TOPLEFT", 16, channelY - 20)
    self.emptyChannels:ClearAllPoints()
    self.emptyChannels:SetPoint("TOPLEFT", 20, channelY - 50)
    local channels = self:GetChannels()
    for index, channel in ipairs(channels) do
        local button = self.channelButtons[index]
        if not button then
            button = toggle(self.content, "", 12, 0,
                function(checked)
                    local current = self.channelButtons[index]
                    self.db.channels[current.channelKey] = checked
                end)
            self.channelButtons[index] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 12, channelY - 48 - (index - 1) * 30)
        button.channelKey = channel.key
        button.Text:SetText(channel.id .. ". " .. channel.name:gsub("|", "||"))
        button:SetChecked(self.db.channels[channel.key] == true)
        button:SetEnabled(true)
        button:Show()
    end
    for index = #channels + 1, #self.channelButtons do
        self.channelButtons[index]:Hide()
    end
    self.emptyChannels:SetShown(#channels == 0)
    self.content:SetHeight(-channelY + 60 + math.max(1, #channels) * 30)
end

function Bruh:CreatePrompt()
    local prompt = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    prompt:SetSize(420, 140)
    prompt:SetPoint("CENTER", 0, 170)
    prompt:SetFrameStrata("DIALOG")
    prompt:SetClampedToScreen(true)
    prompt:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    label(prompt, "Foxyy Bruh - click to reply", 18, -16, "GameFontNormalLarge")
    self.promptLabel = label(prompt, "", 18, -43, "GameFontHighlight")
    self.promptLabel:SetWidth(380)
    self.promptLabel:SetHeight(48)
    self.promptLabel:SetJustifyH("LEFT")
    local send = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
    send:SetSize(170, 26)
    send:SetPoint("BOTTOMLEFT", 18, 18)
    send:SetText("Send reply")
    send:SetScript("OnClick", function()
        self:SendPending()
    end)
    self.promptSend = send
    local cancel = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
    cancel:SetSize(100, 26)
    cancel:SetPoint("BOTTOMRIGHT", -18, 18)
    cancel:SetText("Dismiss")
    cancel:SetScript("OnClick", function()
        self:ClearPending()
    end)
    local elapsed = 0
    prompt:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            self:ValidatePending()
        end
    end)
    prompt:Hide()
    self.prompt = prompt
end

function Bruh:ShowPrompt(destination, word)
    self.promptLabel:SetText(destination:gsub("|", "||") .. "\nReply: " .. word
        .. "\nExpires after 3 seconds. No replies are queued.")
    self.prompt:Show()
end

function Bruh:HidePrompt()
    if self.prompt then
        self.prompt:Hide()
    end
end

function Bruh:CreateOptions()
    local panel = CreateFrame("Frame", "FoxyyBruhOptions", UIParent)
    panel.name = "Foxyy Bruh"
    panel:Hide()
    panel:SetSize(660, 580)
    label(panel, "Foxyy Bruh", 16, -16, "GameFontNormalLarge")
    local description = label(panel,
        "Echo enabled words exactly. Cooldown: 3 seconds per conversation.\n"
        .. "Numbered channels and outdoor say/yell need a click. Chat lockdown skips replies.\n"
        .. "Cooldowns limit echo chains; they do not guarantee prevention.",
        16, -44, "GameFontHighlightSmall")
    description:SetJustifyH("LEFT")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -98)
    scroll:SetPoint("BOTTOMRIGHT", -32, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(590, 420)
    scroll:SetScrollChild(content)
    self.panel, self.content = panel, content
    self.chatButtons, self.channelButtons, self.wordRows = {}, {}, {}
    self.master = toggle(content, "Enable automatic replies", 0, 0,
        function(checked)
            self.db.enabled = checked
        end)
    label(content, "Words to echo", 16, -42)
    label(content, "Add a word, switch it on/off, or remove it (including bruh).", 16, -66,
        "GameFontHighlightSmall")
    self.wordInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    self.wordInput:SetSize(230, 28)
    self.wordInput:SetPoint("TOPLEFT", 20, -90)
    self.wordInput:SetAutoFocus(false)
    self.wordInput:SetMaxLetters(255)
    self.wordError = label(content, "", 20, -124, "GameFontHighlightSmall")
    self.wordError:SetTextColor(1, 0.35, 0.35)
    local function addWord()
        local ok, message = self:AddWord(self.wordInput:GetText())
        self.wordError:SetText(message or "")
        if ok then
            self.wordInput:SetText("")
            self.wordInput:ClearFocus()
        end
    end
    self.wordInput:SetScript("OnEnterPressed", addWord)
    self.wordInput:SetScript("OnEscapePressed", function(input)
        input:ClearFocus()
    end)
    self.addWordButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.addWordButton:SetSize(80, 26)
    self.addWordButton:SetPoint("TOPLEFT", 264, -90)
    self.addWordButton:SetText("Add word")
    self.addWordButton:SetScript("OnClick", addWord)
    self.emptyWords = label(content, "No words configured. Add a word above to enable replies.",
        20, -154, "GameFontHighlight")
    self.chatHeading = label(content, "Chats", 16, 0)
    for _, entry in ipairs(self.chatTypes) do
        local chatType = entry[1]
        self.chatButtons[chatType] = toggle(content, entry[2], 12, 0,
            function(checked)
                self.db.chats[chatType] = checked
            end)
    end
    self.channelHeading = label(content, "Joined channels (choices saved by name)", 16, 0)
    self.channelHint = label(content,
        "Off by default. Switches remain editable while chat is unavailable.",
        16, 0, "GameFontHighlightSmall")
    self.emptyChannels = label(content, "No numbered channels joined.", 20, 0, "GameFontHighlight")
    panel:SetScript("OnShow", function()
        self:RefreshOptions()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        self.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(self.category)
    else
        panel:SetPoint("CENTER")
        local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        close:SetSize(80, 24)
        close:SetPoint("TOPRIGHT", -12, -12)
        close:SetText("Close")
        close:SetScript("OnClick", function()
            panel:Hide()
        end)
    end
    self:CreatePrompt()
    self:RefreshOptions()
end

function Bruh:OpenOptions()
    if self.category and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    elseif self.panel then
        self.panel:SetShown(not self.panel:IsShown())
    end
end

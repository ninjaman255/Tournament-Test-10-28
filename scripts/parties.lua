-- parties.lua
local Parties = {}
local Displayer = require("scripts/displayer/displayer")
Parties.__index = Parties

-- Configuration
Parties.MAX_PARTY_SIZE = 4      -- Maximum players per party
Parties.COUNTDOWN_DURATION = 60 -- Default countdown in seconds
Parties.DISPLAY_POSITION_X = 10 -- X position for countdown display
Parties.DISPLAY_POSITION_Y = 90 -- Y position for countdown display

-- Party management
Parties.list = {}
Parties.nextPartyId = 1

function Parties.create()
    local self = setmetatable({}, Parties)
    self.id = Parties.nextPartyId
    Parties.nextPartyId = Parties.nextPartyId + 1
    self.members = {}
    self.countdown = nil
    self.countdownValue = 0
    self.countdownDisplayIds = {} -- Store display IDs for each member
    Parties.list[self.id] = self
    return self
end

function Parties:addPlayer(playerId)
    if #self.members >= Parties.MAX_PARTY_SIZE then
        return false, "Party is full"
    end

    -- Remove player from any existing party first
    Parties.removePlayerFromAllParties(playerId)

    table.insert(self.members, playerId)

    -- Initialize display ID for this player
    self.countdownDisplayIds[playerId] = nil

    return true
end

function Parties:removePlayer(playerId)
    for i, memberId in ipairs(self.members) do
        if memberId == playerId then
            table.remove(self.members, i)

            -- Clear countdown display for this player
            self:clearPlayerDisplay(playerId)

            -- Remove from display IDs
            self.countdownDisplayIds[playerId] = nil

            -- If party becomes empty, remove it
            if #self.members == 0 then
                self:stopCountdown()
                Parties.list[self.id] = nil
            end

            return true
        end
    end
    return false
end

function Parties:isFull()
    return #self.members >= Parties.MAX_PARTY_SIZE
end

function Parties:startCountdown(duration)
    duration = duration or Parties.COUNTDOWN_DURATION
    self.countdown = duration
    self.countdownValue = duration

    -- Create countdown displays for all members
    self:createCountdownDisplays()

    -- Update displays with initial value
    self:updateCountdownDisplays()
end

function Parties:stopCountdown()
    self.countdown = nil
    self.countdownValue = 0

    -- Clear displays for all members
    self:clearAllDisplays()
end

function Parties:createCountdownDisplays()
    for _, playerId in ipairs(self.members) do
        self:createPlayerDisplay(playerId)
    end
end

function Parties:createPlayerDisplay(playerId)
    -- Clear any existing display first
    self:clearPlayerDisplay(playerId)

    -- Create countdown display using Displayer API (similar to main.lua example)
    local displayId = "party_countdown_" .. self.id
    self.countdownDisplayIds[playerId] = displayId

    -- Create the countdown display
    Displayer.TimerDisplay.createPlayerCountdownDisplay(
        playerId,
        displayId,
        Parties.DISPLAY_POSITION_X,
        Parties.DISPLAY_POSITION_Y,
        "default"
    )

    -- Add a label above the countdown (like in main.lua)
    Displayer.Text.drawText(
        playerId,
        "PARTY STARTING",
        Parties.DISPLAY_POSITION_X + 2,
        Parties.DISPLAY_POSITION_Y - 10,
        "THICK",
        0.7,
        100
    )
end

function Parties:updateCountdownDisplays()
    if not self.countdown then return end

    for _, playerId in ipairs(self.members) do
        local displayId = self.countdownDisplayIds[playerId]
        if displayId then
            -- Update the countdown display (like in main.lua)
            Displayer.TimerDisplay.updatePlayerCountdownDisplay(
                playerId,
                displayId,
                self.countdownValue
            )
        end
    end
end

function Parties:clearPlayerDisplay(playerId)
    local displayId = self.countdownDisplayIds[playerId]
    if displayId then
        -- Remove the countdown display
        Displayer.TimerDisplay.removePlayerDisplay(playerId, displayId)

        -- Also remove the label text
        Displayer.Text.removeText(playerId, "party_label_" .. self.id)

        self.countdownDisplayIds[playerId] = nil
    end
end

function Parties:clearAllDisplays()
    for playerId, displayId in pairs(self.countdownDisplayIds) do
        if displayId then
            Displayer.TimerDisplay.removePlayerDisplay(playerId, displayId)
            Displayer.Text.removeText(playerId, "party_label_" .. self.id)
        end
    end
    self.countdownDisplayIds = {}
end

function Parties:updateCountdown()
    if not self.countdown then return end

    self.countdown = self.countdown - 1
    self.countdownValue = self.countdown

    -- Update display for all members (showing same value to everyone)
    self:updateCountdownDisplays()

    -- Countdown finished
    if self.countdown <= 0 then
        self:onCountdownComplete()
        self:stopCountdown()
    end
end

function Parties:onCountdownComplete()
    -- Override this function for countdown completion logic
    print("Party " .. self.id .. " countdown completed!")

    -- Show completion message to all party members (like in main.lua)
    for _, playerId in ipairs(self.members) do
        Displayer.Text.createTextBox(
            playerId,
            "party_complete_" .. self.id,
            "Party starting now!\nGet ready!",
            Parties.DISPLAY_POSITION_X + 50,
            Parties.DISPLAY_POSITION_Y,
            80,
            30,
            "THICK",
            0.8,
            100,
            {
                x = Parties.DISPLAY_POSITION_X + 45,
                y = Parties.DISPLAY_POSITION_Y - 5,
                width = 90,
                height = 40,
                padding_x = 4,
                padding_y = 4
            },
            35
        )
    end

    -- Add your game start logic here
end

-- Static methods
function Parties.findAvailableParty()
    for _, party in pairs(Parties.list) do
        if not party:isFull() then
            return party
        end
    end
    return nil
end

function Parties.getPlayerParty(playerId)
    for _, party in pairs(Parties.list) do
        for _, memberId in ipairs(party.members) do
            if memberId == playerId then
                return party
            end
        end
    end
    return nil
end

function Parties.removePlayerFromAllParties(playerId)
    local party = Parties.getPlayerParty(playerId)
    if party then
        party:removePlayer(playerId)
        return true
    end
    return false
end

function Parties.autoJoinOrCreate(playerId)
    -- Try to find available party first
    local availableParty = Parties.findAvailableParty()

    if availableParty then
        local success = availableParty:addPlayer(playerId)
        if success and availableParty:isFull() then
            -- Start countdown if party becomes full
            availableParty:startCountdown(30) -- 30 second countdown when full
        end
        return success, availableParty
    else
        -- Create new party
        local newParty = Parties.create()
        local success = newParty:addPlayer(playerId)
        return success, newParty
    end
end

function Parties.clearParty(partyId)
    local party = Parties.list[partyId]
    if party then
        party:stopCountdown()
        Parties.list[partyId] = nil
        return true
    end
    return false
end

function Parties.clearAllParties()
    for partyId, party in pairs(Parties.list) do
        party:stopCountdown()
    end
    Parties.list = {}
    Parties.nextPartyId = 1
end

function Parties.getPartyCount()
    local count = 0
    for _ in pairs(Parties.list) do
        count = count + 1
    end
    return count
end

function Parties.getTotalPlayers()
    local count = 0
    for _, party in pairs(Parties.list) do
        count = count + #party.members
    end
    return count
end

-- Tick update function (call this from your main onTick)
function Parties.onTick()
    for _, party in pairs(Parties.list) do
        party:updateCountdown()
    end
end

-- Utility functions
function Parties.printDebugInfo()
    print("=== Parties Debug Info ===")
    print("Total parties: " .. Parties.getPartyCount())
    print("Total players: " .. Parties.getTotalPlayers())

    for partyId, party in pairs(Parties.list) do
        print("Party " .. partyId .. " (" .. #party.members .. "/" .. Parties.MAX_PARTY_SIZE .. "): " ..
            table.concat(party.members, ", "))
        if party.countdown then
            print("  Countdown: " .. party.countdown .. "s")
        end
    end
    print("==========================")
end

-- Player join/leave handlers (integrate these with your main game)
function Parties.onPlayerJoin(playerId)
    local success, party = Parties.autoJoinOrCreate(playerId)
    if success then
        print("Player " .. playerId .. " joined party " .. party.id)

        -- Hide default HUD for the player (like in main.lua)
        Displayer:hidePlayerHUD(playerId)

        -- Show party status message
        Displayer.Text.createTextBox(
            playerId,
            "party_welcome",
            "Joined Party " .. party.id .. "\nMembers: " .. #party.members .. "/" .. Parties.MAX_PARTY_SIZE,
            Parties.DISPLAY_POSITION_X + 60,
            Parties.DISPLAY_POSITION_Y - 30,
            70,
            35,
            "THICK",
            0.7,
            100,
            nil,
            30
        )
    else
        print("Failed to add player " .. playerId .. " to party")
    end
end

function Parties.onPlayerLeave(playerId)
    Parties.removePlayerFromAllParties(playerId)
end

-- Command handlers for testing
function Parties.testCommand(playerId, command)
    if command == "debug" then
        Parties.printDebugInfo()
    elseif command == "clear" then
        Parties.clearAllParties()
        Displayer.Text.drawText(playerId, "All parties cleared", 10, 120, "THICK", 0.7, 100)
    end
end

return Parties

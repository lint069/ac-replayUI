
local replay_control = require 'shared/ui/replay'

ui.setAsynchronousImagesLoading(true)

local settings = ac.storage {
    useCustomFolders = true,
}

local replay = {
    play = false,
    rewind = false,
    frame = 0,
    length = 0, --in seconds
    speed = 1 --speed multiplier
}

local window = {
    pos = vec2(),
    size = vec2()
}

local colors = {
    buttonIdle = rgbm(0.78, 0.77, 0.76, 1),
    buttonActive = rgbm(0.98, 0.97, 0.96, 1),
    buttonExitHovered = rgbm(0.96, 0.17, 0.23, 1),
    timeline = {
        unplayed = rgbm(0.3, 0.3, 0.3, 1),
        played = rgbm(0.9, 0.9, 0.9, 1),
        circle = rgbm(0.9, 0.9, 0.9, 1),
        circleBorder = rgbm(0.95, 0.95, 0.95, 0.95)
    }
}

local app = {
    images = {
        playpause = '.\\assets\\img\\playpause.png',
        exit = '.\\assets\\img\\exit.png',
        seek = '.\\assets\\img\\seek.png',
        save = '.\\assets\\img\\save.png',
    },
    font = ui.DWriteFont('Geist', '.\\assets\\font\\Geist-Regular.ttf'):spacing(-0.4, 0, 4)
}

local replayQualityPresets = {
    [0] = 8,
    [1] = 12,
    [2] = 16.6666667,
    [3] = 33.3333333,
    [4] = 66.6666667,
}

local sim = ac.getSim()

local replayConfigIni = ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. '/replay.ini', ac.INIFormat.Extended)
local replayQuality = replayConfigIni:get('QUALITY', 'LEVEL', 3)
local replayHz = replayQualityPresets[replayQuality]

--#region helper functions

---@param sec number
---@return number hrs
---@return number min
---@return number sec
local function timeFromSeconds(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    return h, m, s
end

---@param hrs number
---@param min number
---@param sec number
---@return string @Formatted time string (H:MM:SS or MM:SS).
local function formatTime(hrs, min, sec)
    if hrs > 0 then
        return string.format('%d:%02d:%02d', hrs, min, sec)
    end
    return string.format('%d:%02d', min, sec)
end

--#endregion

--#region drawing functions

local padding = vec2(4, 7)
local function drawTimeline()
    local progress = replay.frame / sim.replayFrames
    local lineStart = vec2(80, 60)
    local lineEnd = vec2(window.size.x - lineStart.x, lineStart.y)
    local lineThickness = 4

    ui.drawSimpleLine(lineStart, lineEnd, colors.timeline.unplayed, lineThickness)
    ui.drawSimpleLine(lineStart, vec2(math.clampN(lineStart.x + progress * (lineEnd.x - lineStart.x), lineStart.x, lineEnd.x), lineEnd.y), colors.timeline.played, lineThickness)

    local cursor = vec2(math.clampN(lineStart.x + progress * (lineEnd.x - lineStart.x), lineStart.x, lineEnd.x), lineStart.y)
    ui.drawCircleFilled(cursor, 5, colors.timeline.circle)
    ui.drawCircle(cursor, 5, colors.timeline.circleBorder)

    ui.pushDWriteFont(app.font)

    local currentHrs, currentMin, currentSec = timeFromSeconds(math.clampN(replay.frame / replayHz, 0, replay_control.getReplayTotalTime()))
    ui.dwriteDrawText(formatTime(currentHrs, currentMin, currentSec), 14, vec2(22, lineStart.y - 10))

    local hrs, min, sec = timeFromSeconds(replay_control.getReplayTotalTime())
    ui.dwriteDrawText(formatTime(hrs, min, sec), 14, vec2(window.size.x - 60, lineEnd.y - 10))

    ui.popDWriteFont()

    local timelineWidth = (lineEnd.x - lineStart.x)
    if ui.rectHovered(lineStart - padding, lineEnd + padding) then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseDown(ui.MouseButton.Left) or ui.isMouseDragging(ui.MouseButton.Left) then
            padding = vec2(30, 30)
            local mouseRelative = math.clampN(ui.mouseLocalPos().x - lineStart.x, 0, timelineWidth)
            local frame = (mouseRelative / timelineWidth) * sim.replayFrames

            replay.frame = frame
            ac.setReplayPosition(replay.frame, 1)
        else
            padding = vec2(4, 7)
        end
    end
end


local function drawButtons(winHalfSize)
    local buttonSize = vec2(35, 35)

    --exit button
    local isHovered = ui.rectHovered(vec2(50, 95), vec2(50, 95) + buttonSize)
    local color = isHovered and colors.buttonExitHovered or colors.buttonIdle

    ui.drawImage(app.images.exit, vec2(50, 95), vec2(50, 95) + buttonSize, color)

    if isHovered then
        ui.setMouseCursor(ui.MouseCursor.Hand)
        if ui.mouseReleased(ui.MouseButton.Left) then
            ac.tryToToggleReplay(false)
        end
    end














    --stop button
    local isHovered = ui.rectHovered(vec2(455, 100), vec2(445, 90) + buttonSize)
    local color = isHovered and colors.buttonActive or colors.buttonIdle

    if isHovered then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseClicked(ui.MouseButton.Left) then
            replay.play = false
            replay.frame = 0
            ac.setReplayPosition(replay.frame, 1)
        end
    end

    ui.drawRectFilled(vec2(455, 100), vec2(445, 90) + buttonSize, color, 1.5)















    --play/pause button
    if replay.play then
        ui.drawImage(app.images.playpause, vec2(winHalfSize - 15, 95), vec2(winHalfSize + 15, 125), colors.buttonActive, vec2(2 / 2, 0), vec2(1 / 2, 1))
    else
        ui.drawImage(app.images.playpause, vec2(winHalfSize - 15, 95), vec2(winHalfSize + 15, 125), colors.buttonActive, vec2(0 / 2, 0), vec2(1 / 2, 1))
    end

    if ui.rectHovered(vec2(winHalfSize - 15, 95), vec2(winHalfSize + 15, 125)) then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseClicked(ui.MouseButton.Left) then
            replay.speed = 1
            replay.play = not replay.play
        end
    end

    --seek buttons
    ui.drawImage(app.images.seek, vec2(winHalfSize - 50, 92.5), vec2(winHalfSize - 80, 127.5), colors.buttonActive)
    ui.drawImage(app.images.seek, vec2(winHalfSize + 50, 92.5), vec2(winHalfSize + 80, 127.5), colors.buttonActive)

    --[[
    if ui.button('x Fast Forward', vec2()) then
        replay.speed = replay.speed + 1
        replay.play = true
    end

    if ui.button('x Rewind', vec2()) then
        replay.speed = replay.speed - 1
        replay.rewind = true
        replay.play = true
    end
    ]]
end

local filename = ''
local showTextInput = false
local function drawSaveButton()
    local buttonSize = vec2(35, 35)
    local pressedEnter = false
    local dateTime = os.date('%d-%H%M', os.time())
    local carName, trackName = ac.getCarName(0), ac.getTrackName()
    local replayName = dateTime .. '-' .. carName .. '-' .. trackName

    replayName = replayName:gsub("%s+", "-")

    local isHovered = ui.rectHovered(vec2(300, 95), vec2(300, 95) + buttonSize)
    local color = (isHovered or showTextInput) and colors.buttonActive or colors.buttonIdle

    if isHovered then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseClicked(ui.MouseButton.Left) then
            showTextInput = not showTextInput
            if showTextInput then filename = replayName end
        end
    end

    ui.drawImage(app.images.save, vec2(300, 95), vec2(300, 95) + buttonSize, color)

    ui.setCursor(vec2(0, 0))
    if showTextInput then
        filename, _, pressedEnter = ui.inputText('', filename)
    end

    local date = os.date('%m-%y')
    local replaysFolder = ac.getFolder(ac.FolderID.Replays)
    local filePath = replaysFolder .. '\\' .. filename .. '.acreplay'
    local dateFolderPath = replaysFolder .. '\\' .. date

    if showTextInput then
        ui.sameLine()
        if ui.iconButton(ui.Icons.Save, vec2(45, 22)) or pressedEnter then
            showTextInput = false

            if not replay_control.saveReplay(filename) then
                ui.toast(ui.Icons.Warning, 'Can\'t use special characters.')
                return
            end

            if settings.useCustomFolders then
                if not io.dirExists(dateFolderPath) then
                    io.createDir(dateFolderPath)
                end

                if io.fileExists(filePath) then
                    io.move(filePath, dateFolderPath .. '\\' .. filename .. '.acreplay')
                end
            end
        end
    end
end

--#endregion

ui.onExclusiveHUD(function(mode)
    if mode ~= 'replay' then return end

    ui.transparentWindow('replayUI', window.pos, window.size, false, true, function()
        window.size = vec2(1200, 130 + 30)
        window.pos = vec2((sim.windowSize.x / 2) - (window.size.x / 2), (sim.windowSize.y - 180) - (window.size.y / 2))

        ui.drawRectFilled(vec2(0, 30), window.size, rgbm(0, 0, 0, 0.3), 8, ui.CornerFlags.Top)

        local winHalfSize = ui.windowWidth() / 2

        drawTimeline()
        drawButtons(winHalfSize)
        drawSaveButton()
    end)
end)

function script.update(dt)
    replay.length = replay_control.getReplayTotalTime()

    if replay.frame >= sim.replayFrames then
        replay.play = false
        replay.speed = 1
    end

    if replay.play then
        replay.frame = replay.frame + (dt * replayHz) * replay.speed
        ac.setReplayPosition(replay.frame, 1)
    end
end

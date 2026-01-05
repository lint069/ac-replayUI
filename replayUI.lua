---@diagnostic disable: lowercase-global

require 'stepper'
local replay_control = require 'shared/ui/replay'

local settings = ac.storage {
    useCustomFolders = true,
    excludeAIFromCarList = true,
}

local replay = {
    play = false,
    rewind = false,
    frame = 0,
    length = 0, --in seconds
    speed = 1,
}

local window = {
    position = vec2(),
    size = vec2(),
}

local colors = {
    buttonIdle = rgbm(0.78, 0.77, 0.76, 1),
    buttonHovered = rgbm(0.95, 0.94, 0.93, 1),
    buttonExitHovered = rgbm(0.97, 0.13, 0.23, 1),
    timeline = {
        unplayed = rgbm(0.3, 0.3, 0.3, 1),
        played = rgbm(0.85, 0.85, 0.85, 1),
        circle = rgbm(0.9, 0.9, 0.9, 1),
        circleBorder = rgbm(0.95, 0.95, 0.95, 0.95),
    },
    stepper = {
        background = rgbm(0.5, 0.5, 0.5, 0.1),
        border = rgbm(1, 1, 1, 0.5),
    },
}

local app = {
    images = {
        playpause = '.\\assets\\img\\playpause.png',
        exit = '.\\assets\\img\\exit.png',
        seek = '.\\assets\\img\\seek.png',
        save = '.\\assets\\img\\save.png',
        sort = '.\\assets\\img\\sort.png',
        stop = '.\\assets\\img\\stop.png',
    },
    font = {
        regular = ui.DWriteFont('Geist', '.\\assets\\font\\Geist-Regular.ttf'):spacing(-0.4, 0, 4),
        medium = ui.DWriteFont('Geist', '.\\assets\\font\\Geist-Medium.ttf'),
    },
}

local replayQualityPresets = {
    [0] = 8,
    [1] = 12,
    [2] = 16.6666667,
    [3] = 33.3333333,
    [4] = 66.6666667,
}

local sim = ac.getSim()

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
    if hrs > 0 then return string.format('%d:%02d:%02d', hrs, min, sec) end
    return string.format('%d:%02d', min, sec)
end

--#endregion

--#region drawing functions

local padding = vec2(4, 7)
local replayConfig = ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. '/replay.ini', ac.INIFormat.Extended)
local replayQuality = replayConfig:get('QUALITY', 'LEVEL', 3)
local replayHz = replayQualityPresets[replayQuality]

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

    local timeFontSize = 14
    local timeTextSize = ui.measureDWriteText('00:00:00', timeFontSize)
    local currentHrs, currentMin, currentSec = timeFromSeconds(math.clampN(replay.frame / replayHz, 0, replay.length))
    local hrs, min, sec = timeFromSeconds(replay.length)

    ui.pushDWriteFont(app.font.regular)

    ui.setCursor(vec2(lineStart.x - 65, lineStart.y - 9))
    ui.dwriteTextAligned(formatTime(currentHrs, currentMin, currentSec), timeFontSize, ui.Alignment.Center, ui.Alignment.Start, timeTextSize)

    ui.setCursor(vec2(lineEnd.x + 15, lineEnd.y - 9))
    ui.dwriteTextAligned(formatTime(hrs, min, sec), timeFontSize, ui.Alignment.Center, ui.Alignment.Start, timeTextSize)

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

---@param y number y-position
local function drawExitButton(y)
    local size = 40
    local pos = vec2(175, y + (50 - size) * 0.5)

    local hovered = ui.rectHovered(pos, pos + size)
    local color = hovered and colors.buttonExitHovered or colors.buttonIdle

    ui.drawImage(app.images.exit, pos, pos + size, color)

    if hovered then
        ui.setMouseCursor(ui.MouseCursor.Hand)
        if ui.mouseReleased(ui.MouseButton.Left) then
            ac.tryToToggleReplay(false)
        end
    end
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
    local color = (isHovered or showTextInput) and colors.buttonHovered or colors.buttonIdle

    if isHovered then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseReleased(ui.MouseButton.Left) then
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




local function drawPlaybackButtons(winHalfSize)
    local buttonSize = vec2(35, 35)

    --stop button
    local isHovered = ui.rectHovered(vec2(455, 100), vec2(445, 90) + buttonSize)
    local color = isHovered and colors.buttonHovered or colors.buttonIdle

    if isHovered then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseReleased(ui.MouseButton.Left) then
            replay.play = false
            replay.frame = 0
            ac.setReplayPosition(replay.frame, 1)
        end
    end

    ui.drawImage(app.images.stop, vec2(455, 100), vec2(445, 90) + buttonSize, color)

    --play/pause button
    if replay.play then
        ui.drawImage(app.images.playpause, vec2(winHalfSize - 15, 95), vec2(winHalfSize + 15, 125), colors.buttonHovered, vec2(2 / 2, 0), vec2(1 / 2, 1))
    else
        ui.drawImage(app.images.playpause, vec2(winHalfSize - 15, 95), vec2(winHalfSize + 15, 125), colors.buttonHovered, vec2(0 / 2, 0), vec2(1 / 2, 1))
    end

    if ui.rectHovered(vec2(winHalfSize - 15, 95), vec2(winHalfSize + 15, 125)) then
        ui.setMouseCursor(ui.MouseCursor.Hand)

        if ui.mouseReleased(ui.MouseButton.Left) then
            replay.speed = 1
            replay.play = not replay.play
        end
    end

    --seek buttons
    ui.drawImage(app.images.seek, vec2(winHalfSize - 50, 92.5), vec2(winHalfSize - 80, 127.5), colors.buttonHovered)
    ui.drawImage(app.images.seek, vec2(winHalfSize + 50, 92.5), vec2(winHalfSize + 80, 127.5), colors.buttonHovered)

    --[[
        replay.speed = +2
        replay.speed = -2
    ]]
end




local cameras = {
    { type = 'Cockpit', label = 'Cockpit' },
    { type = 'Chase', label = 'Chase' },
    { type = 'Chase2', label = 'Chase 2' },
    { type = 'Bonnet', label = 'Bonnet' },
    { type = 'Bumper', label = 'Bumper' },
    { type = 'Dash', label = 'Dash' },
    { type = 'Helicopter', label = 'Helicopter' },
}

local cameraIndex = 1
local cameraTextOpacity = 0

ac.onReplay(function(event) if event ~= 'start' then return end cameraTextOpacity = 5 end)

local totalTrackCameras = sim.trackCamerasSetsCount
for i = 0, totalTrackCameras - 1 do
    cameras[#cameras + 1] = {index = i, label = 'Track ' .. (i + 1)}
end

local function drawCameraButton()
    local pos = vec2(755, 93)
    local size = vec2(100, 35)

    local hoveredLeft, hoveredRight = drawNumericStepper(pos, size, colors.stepper.border, colors.stepper.background, 1, 0.15, 6)

    if hoveredLeft or hoveredRight then
        if ui.mouseReleased(ui.MouseButton.Left) then
            cameraTextOpacity = 5

            cameraIndex = (cameraIndex - 1 + (hoveredLeft and -1 or 1)) % #cameras + 1

            if cameraIndex >= 2 and cameraIndex <= 6 then
                ac.setCurrentCamera(ac.CameraMode.Drivable)
                ac.setCurrentDrivableCamera(ac.DrivableCamera[cameras[cameraIndex].type])
            elseif cameraIndex >= 8 then
                ac.setCurrentCamera(ac.CameraMode.Track)
                ac.setCurrentTrackCamera(cameras[cameraIndex].index)
            else
                ac.setCurrentCamera(ac.CameraMode[cameras[cameraIndex].type])
            end
        end
    end

    local cameraFontSize, numberFontSize = 14, 17
    local cameraTextSize = ui.measureDWriteText('Helicopter', cameraFontSize)
    local numberTextSize = ui.measureDWriteText('00', numberFontSize)

    ui.setCursor(vec2(796, 99))
    ui.pushDWriteFont(app.font.medium)
    ui.dwriteTextAligned(tostring(cameraIndex), numberFontSize, ui.Alignment.Center, ui.Alignment.Start, numberTextSize)
    ui.popDWriteFont()

    ui.setCursor(vec2(773, 134))
    ui.pushDWriteFont(app.font.regular)
    ui.dwriteTextAligned(cameras[cameraIndex].label, cameraFontSize, ui.Alignment.Center, ui.Alignment.Start, cameraTextSize, false, rgbm(0.92, 0.91, 0.9, cameraTextOpacity))
    ui.popDWriteFont()
end

--#endregion

ui.onExclusiveHUD(function(mode)
    if mode ~= 'replay' then return end

    ui.transparentWindow('replayUI', window.position, window.size, false, true, function()
        window.size = vec2(1200, 130 + 30)
        window.position = vec2((sim.windowSize.x / 2) - (window.size.x / 2), (sim.windowSize.y - 180) - (window.size.y / 2))

        ui.drawRectFilled(vec2(0, 30), window.size, rgbm(0, 0, 0, 0.4), 8, ui.CornerFlags.Top)

        local winHalfSize = ui.windowWidth() / 2
        local buttonRow = (ui.windowHeight() / 2) + 5

        drawTimeline()

        drawExitButton(buttonRow)
        drawPlaybackButtons(winHalfSize)
        drawSaveButton()
        drawCameraButton()
    end)
end)

function script.update(dt)
    cameraTextOpacity = cameraTextOpacity - dt

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

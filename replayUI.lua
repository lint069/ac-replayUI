
local replay_control = require 'shared/ui/replay'

local settings = ac.storage {
    useCustomFolders = true,
}

local replay = {
    play = false,
    rewind = false,
    frame = 0,
    length = 0, --in seconds
    speed = 1
}

local window = {
    position = vec2(),
    size = vec2()
}

local colors = {
    buttonIdle = rgbm(0.78, 0.77, 0.76, 1),
    buttonActive = rgbm(0.92, 0.91, 0.9, 1),
    buttonDown = rgbm(1, 0.99, 0.98, 1),
    buttonExitHovered = rgbm(0.96, 0.17, 0.23, 1),
    timeline = {
        unplayed = rgbm(0.3, 0.3, 0.3, 1),
        played = rgbm(0.9, 0.9, 0.9, 1),
        circle = rgbm(0.9, 0.9, 0.9, 1),
        circleBorder = rgbm(0.95, 0.95, 0.95, 0.95)
    },
    stepper = {
        background = rgbm(0.5, 0.5, 0.5, 0.1),
        border = rgbm(1, 1, 1, 0.5)
    }
}

local app = {
    images = {
        playpause = '.\\assets\\img\\playpause.png',
        exit = '.\\assets\\img\\exit.png',
        seek = '.\\assets\\img\\seek.png',
        save = '.\\assets\\img\\save.png',
        sort = '.\\assets\\img\\sort.png'
    },
    font = {
        regular = ui.DWriteFont('Geist', '.\\assets\\font\\Geist-Regular.ttf'):spacing(-0.4, 0, 4),
        medium = ui.DWriteFont('Geist', '.\\assets\\font\\Geist-Medium.ttf')
    }
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
    if hrs > 0 then return string.format('%d:%02d:%02d', hrs, min, sec) end
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

    local timeTextSize = 14
    local currentHrs, currentMin, currentSec = timeFromSeconds(math.clampN(replay.frame / replayHz, 0, replay_control.getReplayTotalTime()))
    local hrs, min, sec = timeFromSeconds(replay_control.getReplayTotalTime())

    ui.pushDWriteFont(app.font.regular)
    ui.dwriteDrawText(formatTime(currentHrs, currentMin, currentSec), timeTextSize, vec2(22, lineStart.y - 10))
    ui.dwriteDrawText(formatTime(hrs, min, sec), timeTextSize, vec2(window.size.x - 60, lineEnd.y - 10))
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



local function drawPlaybackButtons(winHalfSize)
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

---@param pos vec2
---@param size vec2
---@param borderColor rgbm
---@param backgroundColor rgbm
---@param rounding number
---@param cornerFlags? ui.CornerFlags
---@param borderThickness number
---@param gap number @Gap in between the interactive areas.
---@param gradientOpacity number
---@return boolean hoveredLeft
---@return boolean hoveredRight
local function drawStepper(pos, size, borderColor, backgroundColor, rounding, cornerFlags, borderThickness, gap, gradientOpacity)
    local hoveredLeft, hoveredRight = false, false
    local middle = pos.x + size.x * 0.5

    if ui.rectHovered(pos, vec2(middle - gap, pos.y + size.y)) then
        ui.setMouseCursor(ui.MouseCursor.Hand)
        hoveredLeft = true
    end

    if ui.rectHovered(vec2(middle + gap, pos.y), vec2(pos.x + size.x, pos.y + size.y)) then
        ui.setMouseCursor(ui.MouseCursor.Hand)
        hoveredRight = true
    end

    ui.drawRectFilled(pos, pos + size, backgroundColor, rounding, cornerFlags)

    if hoveredLeft then
        ui.beginGradientShade()
        ui.drawRectFilled(pos, vec2(middle + gap, pos.y + size.y), rgbm(1, 1, 1, gradientOpacity), rounding, cornerFlags)
        ui.endGradientShade(pos, vec2(middle + gap, pos.y), rgbm(1, 1, 1, 1), rgbm(backgroundColor.r, backgroundColor.g, backgroundColor.b, 0), true)
    end

    if hoveredRight then
        ui.beginGradientShade()
        ui.drawRectFilled(vec2(middle - gap, pos.y), vec2(pos.x + size.x, pos.y + size.y), rgbm(1, 1, 1, gradientOpacity), rounding, cornerFlags)
        ui.endGradientShade(vec2(middle - gap, pos.y), vec2(pos.x + size.x, pos.y), rgbm(backgroundColor.r, backgroundColor.g, backgroundColor.b, 0), rgbm(1, 1, 1, 1), true)
    end

    ui.drawRect(pos, pos + size, borderColor, rounding, cornerFlags, borderThickness)

    return hoveredLeft, hoveredRight
end

local cameras = {
    'Cockpit',
    'Chase',
    'Chase2',
    'Bonnet',
    'Bumper',
    'Dash',
    'Track',
    'Helicopter',
    'Start',
}

---@param index integer
local function applyCamera(index)
    if index >= 2 and index <= 6 then
        ac.setCurrentCamera(ac.CameraMode.Drivable)
        ac.setCurrentDrivableCamera(ac.DrivableCamera[cameras[index]])
    else
        ac.setCurrentCamera(ac.CameraMode[cameras[index]])
    end
end

local cameraIndex = 1
local cameraTextOpacity = 2
ac.onReplay(function() cameraTextOpacity = 5 end)

local function drawCameraButtons()
    local pos = vec2(755, 92.5)
    local size = vec2(100, 35)
    local colorArrowLeft, colorArrowRight = colors.buttonIdle, colors.buttonIdle

    local hoveredLeft, hoveredRight = drawStepper(pos, size, colors.stepper.border, colors.stepper.background, 6, nil, 1, 15, 0.15)

    if hoveredLeft or hoveredRight then
        local color = ui.mouseDown(ui.MouseButton.Left) and colors.buttonDown or colors.buttonActive

        if hoveredLeft then colorArrowLeft = color else colorArrowRight = color end

        if ui.mouseReleased(ui.MouseButton.Left) then
            cameraIndex = (cameraIndex - 1 + (hoveredLeft and -1 or 1)) % #cameras + 1
            cameraTextOpacity = 5
            applyCamera(cameraIndex)
        end
    end

    ui.drawImage(app.images.sort, vec2(pos.x + 5, pos.y + 8), vec2(pos.x + size.x * 0.5 - 20, pos.y + size.y - 8), colorArrowLeft, vec2(0, 0), vec2(0.5, 1))
    ui.drawImage(app.images.sort, vec2(pos.x + size.x * 0.5 + 20, pos.y + 8), vec2(pos.x + size.x - 5, pos.y + size.y - 8), colorArrowRight, vec2(0.5, 0), vec2(1, 1))

    local cameraTextSize = 14
    local textSize = ui.measureDWriteText('Helicopter', cameraTextSize)
    local alignment = cameraIndex == 1 and 1.5 or 0

    ui.pushDWriteFont(app.font.medium)
    ui.dwriteDrawText(tostring(cameraIndex), cameraTextSize + 2, vec2(800 + alignment, 100))
    ui.popDWriteFont()

    ui.setCursor(vec2(773, 135))
    ui.pushDWriteFont(app.font.regular)
    ui.dwriteTextAligned(cameras[cameraIndex], cameraTextSize, ui.Alignment.Center, ui.Alignment.Start, textSize, false, rgbm(0.92, 0.91, 0.9, cameraTextOpacity))
    ui.popDWriteFont()
end

--#endregion

ui.onExclusiveHUD(function(mode)
    if mode ~= 'replay' then return end

    ui.transparentWindow('replayUI', window.position, window.size, false, true, function()
        window.size = vec2(1200, 130 + 30)
        window.position = vec2((sim.windowSize.x / 2) - (window.size.x / 2), (sim.windowSize.y - 180) - (window.size.y / 2))

        ui.drawRectFilled(vec2(0, 30), window.size, rgbm(0, 0, 0, 0.3), 8, ui.CornerFlags.Top)

        local winHalfSize = ui.windowWidth() / 2

        drawTimeline()
        drawPlaybackButtons(winHalfSize)
        drawSaveButton()
        drawCameraButtons()
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

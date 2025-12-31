---@diagnostic disable: lowercase-global

local colorIdle = rgbm(0.78, 0.77, 0.76, 1)
local colorHovered = rgbm(0.92, 0.91, 0.9, 1)
local colorMouseDown = rgbm(1, 0.99, 0.98, 1)

---@param pos vec2
---@param size vec2
---@param borderColor rgbm
---@param backgroundColor rgbm
---@param borderThickness number
---@param gap number @Gap in between the interactive areas.
---@param gradientOpacity number
---@param rounding? number @Default value: 0.
---@param cornerFlags? ui.CornerFlags @Default value: `ui.CornerFlags.All`.
---@return boolean hoveredLeft
---@return boolean hoveredRight
function drawNumericStepper(pos, size, borderColor, backgroundColor, borderThickness, gap, gradientOpacity, rounding, cornerFlags)
    local colorLeft, colorRight = colorIdle, colorIdle
    local hoveredLeft, hoveredRight = false, false
    local middle = pos.x + size.x * 0.5

    if ui.rectHovered(pos, vec2(middle - gap, pos.y + size.y)) then hoveredLeft = true end
    if ui.rectHovered(vec2(middle + gap, pos.y), vec2(pos.x + size.x, pos.y + size.y)) then hoveredRight = true end

    if hoveredLeft or hoveredRight then ui.setMouseCursor(ui.MouseCursor.Hand) end

    ui.drawRectFilled(pos, pos + size, backgroundColor, rounding, cornerFlags)
    ui.drawRect(pos, pos + size, borderColor, rounding, cornerFlags, borderThickness)

    local mouseDown = ui.mouseDown(ui.MouseButton.Left)

    if hoveredLeft then
        colorLeft = mouseDown and colorMouseDown or colorHovered

        if mouseDown then gradientOpacity = gradientOpacity + 0.05 end

        ui.beginGradientShade()
        ui.drawRectFilled(pos, vec2(middle + gap, pos.y + size.y), rgbm(1, 1, 1, gradientOpacity), rounding, cornerFlags)
        ui.endGradientShade(pos, vec2(middle + gap, pos.y), rgbm(1, 1, 1, 1), rgbm(backgroundColor.r, backgroundColor.g, backgroundColor.b, 0), true)
    end

    if hoveredRight then
        colorRight = mouseDown and colorMouseDown or colorHovered

        if mouseDown then gradientOpacity = gradientOpacity + 0.05 end

        ui.beginGradientShade()
        ui.drawRectFilled(vec2(middle - gap, pos.y), vec2(pos.x + size.x, pos.y + size.y), rgbm(1, 1, 1, gradientOpacity), rounding, cornerFlags)
        ui.endGradientShade(vec2(middle - gap, pos.y), vec2(pos.x + size.x, pos.y), rgbm(backgroundColor.r, backgroundColor.g, backgroundColor.b, 0), rgbm(1, 1, 1, 1), true)
    end

    ui.drawImage('./assets/img/sort.png', vec2(pos.x + 5, pos.y + 8.5), vec2(pos.x + size.x * 0.5 - 23, pos.y + size.y - 8.5), colorLeft, vec2(0, 0), vec2(0.5, 1))
    ui.drawImage('./assets/img/sort.png', vec2(pos.x + size.x * 0.5 + 23, pos.y + 8.5), vec2(pos.x + size.x - 5, pos.y + size.y - 8.5), colorRight, vec2(0.5, 0), vec2(1, 1))

    return hoveredLeft, hoveredRight
end

-- yes, this is ugly.
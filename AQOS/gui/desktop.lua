local buttons = require("./AQOS/gui/widgets/buttons")
local events = require("./AQOS/core/event_handler")


local desktop = {}

-- Stan tylko do optymalizacji
local lastDisplayedTime = ""
local timer_running = false
    

function desktop.initialize()
    local w, h = term.getSize()
    
    term.setBackgroundColor(colors.cyan)
    term.clear()
    
    aqosBtn = buttons.init(nil, 1, h, 4, 1, "aqos", "8", "0")

    -- Narysuj taskbar
    desktop.drawTaskbar()
    timer_running = true
        parallel.waitForAny(
        function()events.listen() end,
        function() while timer_running do desktop.drawTime() end end
    )
end

function desktop.drawTime()
    local w, h = term.getSize()
    
    -- Pobierz aktualny czas
    local czas = os.time()
    local godzina = math.floor(czas)
    local minuty = math.floor((czas - godzina) * 60)
    local dzien = os.day()

    local timeText = string.format("Dzien %d, %02d:%02d", dzien, godzina, minuty)
    
    -- Sprawdź czy czas się zmienił (optymalizacja)
    if timeText == lastDisplayedTime then
        return false -- Nie zmienił się
    end
    
    -- Zachowaj kolory
    local prevBg = term.getBackgroundColor()
    local prevFg = term.getTextColor()
    
    -- Rysuj czas na taskbar
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    
    -- Wyczyść obszar czasu
    term.setCursorPos(w - 15, h)
    term.write(string.rep(" ", 16))
    
    -- Narysuj nowy czas
    term.setCursorPos(w - #timeText + 1, h)
    term.write(timeText)
    
    -- Przywróć kolory
    term.setBackgroundColor(prevBg)
    term.setTextColor(prevFg)
    
    -- Zapisz stan
    lastDisplayedTime = timeText
    return true -- Zmienił się
end

function desktop.drawTaskbar()
    local w, h = term.getSize()
    
    -- Wyczyść całą linię taskbar
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    
    -- Logo systemu
    aqosBtn:draw()
    
    -- Narysuj czas
    desktop.drawTime()
end

function desktop.redraw()
    -- Przerysuj cały pulpit
    local w, h = term.getSize()
    
    -- Tło pulpitu
    term.setBackgroundColor(colors.cyan)
    term.clear()
    
    -- Taskbar
    desktop.drawTaskbar()
    
    -- TODO: Tutaj będą ikony na pulpicie
end

return desktop
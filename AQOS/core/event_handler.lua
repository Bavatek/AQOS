--event_handler.lua

local events = {}
local event_queue = {}
local running = false
local pm = _G.system_pm  -- Bezpośredni dostęp do globalnego PM

-- Start nasłuchiwania (uruchamiany jako proces systemowy)
function events.start()
    running = true
    
    while running do
        local event_data = {os.pullEventRaw()}
        local event_name = event_data[1]
        
        -- PRZECHWYTYWANIE TERMINATE = Ctrl+T od użytkownika (w głównym terminalu)
        if event_name == "terminate" then
            print("")
            print("=== WYKRYTO CTRL+T - ZAMYKANIE SYSTEMU ===")
            
            -- Wyślij specjalny event shutdown do PM
            os.queueEvent("aqos_shutdown")
            
            -- NIE przekazuj terminate dalej
            goto continue
        end
        
        -- Kategoryzuj i dodaj do kolejki wszystkie inne eventy
        events.categorize_event(event_data)
        
        ::continue::
    end
end

-- Kategoryzacja eventów
function events.categorize_event(event_data)
    local event_name = event_data[1]
    
    if event_name == "char" or event_name == "key" or event_name == "key_up" then
        -- Eventy klawiatury
        events.add_to_queue("keyboard", event_data)
        
    elseif event_name == "mouse_click" or event_name == "mouse_scroll" or 
           event_name == "mouse_drag" or event_name == "mouse_up" then
        -- Eventy myszy
        events.add_to_queue("mouse", event_data)
        
    elseif event_name == "timer" then
        -- Eventy czasowe
        events.add_to_queue("timer", event_data)
        
    elseif event_name == "terminate" then
        -- Event terminacji (tylko jeśli dotrze tutaj - normalnie przechwytywany wyżej)
        events.add_to_queue("system", event_data)
        
    elseif event_name == "aqos_shutdown" then
        -- Specjalny event shutdown - nie dodawaj do kolejki
        -- Process Manager sam go obsłuży
        
    else
        -- Wszystkie inne
        events.add_to_queue("system", event_data)
    end
end

-- Dodaj event do kolejki
function events.add_to_queue(category, event_data)
    if not event_queue[category] then
        event_queue[category] = {}
    end
    table.insert(event_queue[category], event_data)
end

-- Funkcja dla modułów - pobierz event z kategorii
function events.get_event(category)
    if event_queue[category] and #event_queue[category] > 0 then
        return table.remove(event_queue[category], 1)  -- FIFO
    end
    return nil
end

-- Sprawdź czy są eventy w kategorii
function events.has_events(category)
    return event_queue[category] and #event_queue[category] > 0
end

-- Debug - pokaż stan kolejek
function events.debug_queues()
    print("=== EVENT HANDLER DEBUG ===")
    for category, queue in pairs(event_queue) do
        print(category .. ": " .. #queue .. " eventów")
    end
    print("Running: " .. tostring(running))
    print("Process Manager: " .. tostring(pm ~= nil))
end

-- Graceful stop
function events.stop()
    print("Event Handler zatrzymywany...")
    running = false
end

return events
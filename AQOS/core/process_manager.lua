--process_manager.lua
local eh = _G.system_eh 

local pm = {}

local processes = {}
local running = false

-- Funkcja do znalezienia następnego dostępnego PID
local function get_next_pid()
    local pid = 1
    while processes[pid] do
        pid = pid + 1
    end
    return pid
end

local function cleanup_closed_tabs()
    if not multishell then return end
    
    for pid, process in pairs(processes) do
        if process.boot == "tab" and process.tab_id and process.active then
            local title = multishell.getTitle(process.tab_id)
            if not title then
                process.active = false
                process.completed = true
                processes[pid] = nil
            end
        end
    end
end

-- Rejestracja procesu z dynamicznym PID
function pm.ps_register(name)
    local pid = get_next_pid()
    
    local process = {
        pid = pid,
        name = name,
        active = false,
        app_path = "function",  -- domyślna wartość placeholder
        args = {},  -- argumenty do uruchomienia
        completed = false,
        boot = "-",
        daemon = false,
        should_terminate = false,  -- flaga gwałtownego przerwania
        pending_app = nil,  -- aplikacja do uruchomienia w terminalu
        window = nil,
        original_term = nil,
        tab_id = nil
    }
    
    processes[pid] = process
    return pid
end

-- Funkcja systemowa
function pm.ps_system(name, func, args)
    local process = pm.ps_status(name)
    if not process then return false end
    
    process.boot = "system"
    process.app_path = func  -- prawdziwa funkcja, nie string
    process.args = args or {}  -- zapisz argumenty
    process.active = true
    process.completed = false
    process.should_terminate = false
    return true
end

-- Event Handler - specjalny proces systemowy z pełnym dostępem do eventów
function pm.ps_event_handler(name, func, args)
    local process = pm.ps_status(name)
    if not process then return false end
    
    process.boot = "event_handler"
    process.app_path = func  -- funkcja event_handler
    process.args = args or {}
    process.active = true
    process.completed = false
    process.should_terminate = false
    return true
end

-- Aplikacja
function pm.ps_app(name, daemon, path, args)
    local process = pm.ps_status(name)
    if not process then return false end
    
    process.boot = "app"
    process.app_path = path
    process.args = args or {}  -- zapisz argumenty
    process.daemon = daemon
    
    if daemon then
        -- ✅ DAEMON - stwórz nowy proces w parallel
        process.active = true
        process.completed = false
        process.should_terminate = false
        return true
    else
        -- ✅ NORMALNA APP - pozostawione systemowi do zarządzania
        process.active = false  -- system sam zdecyduje kiedy uruchomić
        process.completed = false
        process.should_terminate = false
        return true
    end
end

-- Tab z automatycznym cleanup
function pm.ps_tab(name, path, args)
    local process = pm.ps_status(name)
    if not process then return false end
    
    if not multishell then
        return false
    end
    
    process.boot = "tab"
    process.app_path = path  -- ścieżka do pliku
    process.args = args or {}  -- zapisz argumenty
    process.active = true
    process.completed = false
    process.should_terminate = false
    
    local tab_id = multishell.launch(process.args, process.app_path)
    if tab_id and tab_id > 0 then
        process.tab_id = tab_id
        if multishell.setTitle then
            multishell.setTitle(tab_id, process.name)
        end
        return true
    else
        process.completed = true
        return false
    end
end

-- Kill - usuwa proces z listy (z dynamicznym PID)
function pm.ps_kill(name)
    for pid, process in pairs(processes) do
        if process.name == name or process.pid == tonumber(name) then
            if process.boot == "tab" and process.tab_id then
                -- Tab: sprawdź czy zakładka istnieje przed zabiciem
                if multishell and multishell.getTitle then
                    local title = multishell.getTitle(process.tab_id)
                    if title then
                        -- Zakładka istnieje - zabij ją TERMINATE (idzie tylko do taba!)
                        local current_focus = multishell.getFocus()
                        if multishell.setFocus(process.tab_id) then
                            print("DEBUG: Wysyłam terminate do taba (programowy)")
                            os.queueEvent("terminate")  -- ✅ TERMINATE dla tabów
                            sleep(0.1)  -- pozwól procesowi się zakończyć
                            multishell.setFocus(current_focus)  -- wróć do poprzedniej
                        end
                    end
                end
            end
            
            -- Usuń proces z listy (PID będzie automatycznie dostępny dla nowych procesów)
            process.should_terminate = true
            process.active = false
            process.completed = true
            processes[pid] = nil
            return true
        end
    end
    return false
end

-- State - zatrzymuje/wznawia proces (resetuje parallel)
function pm.ps_state(name, state)
    for pid, process in pairs(processes) do
        if process.name == name or process.pid == tonumber(name) then
            
            if state == "active" then
                -- ✅ WZNÓW PROCES
                if process.boot == "tab" then
                    -- Tab: uruchom od nowa z zapisanymi argumentami
                    if not multishell then
                        return false
                    end
                    
                    process.active = true
                    process.completed = false
                    process.should_terminate = false
                    
                    local tab_id = multishell.launch(process.args, process.app_path)
                    if tab_id and tab_id > 0 then
                        process.tab_id = tab_id
                        if multishell.setTitle then
                            multishell.setTitle(tab_id, process.name)
                        end
                        return true
                    else
                        process.completed = true
                        return false
                    end
                else
                    -- System/App/Event_handler: wznów proces
                    process.should_terminate = false
                    process.active = true
                    process.completed = false  -- resetuj flagę completed
                end
                
            elseif state == "unactive" or state == "inactive" then
                -- ❌ ZATRZYMAJ PROCES
                if process.boot == "tab" and process.tab_id then
                    -- Tab: sprawdź czy zakładka istnieje przed zabiciem
                    if multishell and multishell.getTitle then
                        local title = multishell.getTitle(process.tab_id)
                        if title then
                            -- Zakładka istnieje - zabij ją bezpiecznie TERMINATE (idzie tylko do taba!)
                            local current_focus = multishell.getFocus()
                            if multishell.setFocus(process.tab_id) then
                                print("DEBUG: Wysyłam terminate do taba (state - programowy)")
                                os.queueEvent("terminate")  -- ✅ TERMINATE dla tabów
                                sleep(0.1)  -- pozwól procesowi się zakończyć
                                multishell.setFocus(current_focus)  -- wróć do poprzedniej
                            end
                        end
                        -- Oznacz jako nieaktywny (nie usuwaj z listy)
                        process.active = false
                    end
                else
                    -- System/App/Event_handler: zatrzymaj proces - oznacz do zakończenia
                    process.should_terminate = true
                    process.active = false
                    process.completed = true  -- oznacz jako zakończony
                end
                
            else
                -- Nieprawidłowy stan
                print("Nieprawidłowy stan: " .. tostring(state))
                print("Użyj: 'active' lub 'unactive'")
                return false
            end
            
            -- NIE usuwa z listy procesów
            return true
        end
    end
    return false
end

-- Monitor - obsługuje wszystkie typy procesów z automatycznym cleanup
function pm.ps_monitor()
    running = true
    
    while running do
        -- CLEANUP zamkniętych tabów na początku każdej iteracji
        cleanup_closed_tabs()
        
        local runners = {}
        local active_process_count = 0
        
        -- Zlicz aktywne procesy przed dodaniem do runners
        for pid, process in pairs(processes) do
            if process.active and not process.completed then
                active_process_count = active_process_count + 1
                
                if process.boot == "system" then
                    -- ✅ SYSTEM - nadpisany pullEvent dla terminacji
                    table.insert(runners, function() 
                        local old_pullEvent = os.pullEvent
                        os.pullEvent = function(...)
                            if process.should_terminate then
                                error("Process terminated")
                            end
                            return old_pullEvent(...)
                        end
                        
                        -- Przekaż argumenty do funkcji systemowej
                        local success, err = pcall(process.app_path, table.unpack(process.args))
                        
                        -- Przywróć event handler
                        os.pullEvent = old_pullEvent
                        
                        if not success then
                            print("System process error (" .. process.name .. "): " .. tostring(err))
                        end
                        
                        process.completed = true
                    end)
                    
                elseif process.boot == "event_handler" then
                    -- ✅ EVENT_HANDLER - pełny dostęp do eventów, BEZ nadpisywania pullEvent
                    table.insert(runners, function()
                        -- BEZ NADPISYWANIA os.pullEvent dla event_handler!
                        -- Event handler używa pullEventRaw i sam się zarządza
                        local success, err = pcall(process.app_path, table.unpack(process.args))
                        
                        if not success then
                            print("Event_handler error (" .. process.name .. "): " .. tostring(err))
                            sleep(1)  -- delay przed restart
                        end
                        
                        process.completed = true
                    end)
                    
                elseif process.boot == "app" and process.daemon then
                    -- ✅ DAEMON - BEZ nadpisywania os.pullEvent!
                    table.insert(runners, function()
                        -- Zapisz obecny terminal
                        process.original_term = term.current()
                        
                        -- ✅ BEZ NADPISYWANIA os.pullEvent - daemon działa normalnie
                        -- Przekaż argumenty do aplikacji daemon
                        local success, err = pcall(os.run, process.args, process.app_path)
                        
                        -- Przywróć terminal
                        if process.original_term then
                            term.redirect(process.original_term)
                        end
                        
                        if not success then
                            print("Daemon error (" .. process.name .. "): " .. tostring(err))
                        end
                        
                        process.completed = true
                    end)
                end
            end
        end
        
        -- ✅ WATCHDOG z cleanup + AQOS_SHUTDOWN HANDLING
        table.insert(runners, function()
            while true do
                -- Sprawdź czy przyszedł event shutdown
                local event_data = {os.pullEvent()}
                local event_name = event_data[1]
                
                if event_name == "aqos_shutdown" then
                    print("")
                    print("=== CTRL+T SYSTEM SHUTDOWN ===")
                    pm.handle_ctrl_t_shutdown()
                    return
                end
                
                -- Inne eventy - sprawdź procesy
                cleanup_closed_tabs()
                
                local current_count = 0
                for pid, process in pairs(processes) do
                    if process.active and not process.completed then
                        current_count = current_count + 1
                    end
                end
                
                if current_count ~= active_process_count then
                    sleep(0.5)
                    return
                end
                
                for pid, process in pairs(processes) do
                    if process.should_terminate and process.active then
                        process.active = false
                        process.completed = true
                        return
                    end
                end
            end
        end)
        
        if #runners > 1 then  -- >1 bo watchdog zawsze jest dodany
            parallel.waitForAny(unpack(runners))
        else
            -- Znajdź najniższy PID procesu systemowego do wznowienia
            local lowest_system_pid = nil
            for pid, process in pairs(processes) do
                if not process.active and process.boot ~= "tab" then
                    if not lowest_system_pid or pid < lowest_system_pid then
                        lowest_system_pid = pid
                    end
                end
            end
            
            if lowest_system_pid then
                local system_process = processes[lowest_system_pid]
                pm.ps_state(tostring(lowest_system_pid), "active")
                sleep(0.1)
            else
                term.clear()
                term.setCursorPos(1, 1)
                term.setCursorBlink(true)
                print("Brak aktywnych procesow. Nacisnij Q aby wylaczyc.")
                
                local event, button = os.pullEvent("key")
                if event == "key" and button == keys.q then
                    print("Wylaczanie systemu...")
                    os.shutdown()
                    break
                end
            end
        end
    end
end

-- Obsługa Ctrl+T shutdown w Process Manager
function pm.handle_ctrl_t_shutdown()
    print("Zamykanie wszystkich procesów...")
    
    -- Zbierz wszystkie procesy do zamknięcia
    local processes_to_kill = {}
    for pid, process in pairs(processes) do
        if process.name ~= "event_handler" then
            table.insert(processes_to_kill, process)
        end
    end
    
    -- Zamknij wszystkie procesy oprócz event_handler
    for _, process in pairs(processes_to_kill) do
        print("Zamykanie: " .. process.name .. " (" .. process.boot .. ")")
        pm.ps_kill(process.name)
    end
    
    print("Wszystkie procesy zamknięte.")
    
    -- Zatrzymaj Process Manager
    running = false
    
    -- Krótka pauza i shutdown
    sleep(1)
    print("Zamykanie systemu AQOS...")
    os.shutdown()
end

-- Stop monitor
function pm.ps_stop_monitor()
    running = false
end

-- Lista procesów (dla debugowania) - zwraca tylko istniejące procesy
function pm.ps_list()
    return processes
end

-- Status procesu
function pm.ps_status(name)
    for pid, process in pairs(processes) do
        if process.name == name or process.pid == tonumber(name) then
            return process
        end
    end
    return nil
end

-- Debug - wyświetl wszystkie procesy z informacją o PID
function pm.ps_debug()
    print("=== PROCESS MANAGER DEBUG ===")
    
    local sorted_pids = {}
    for pid in pairs(processes) do
        table.insert(sorted_pids, pid)
    end
    table.sort(sorted_pids)
    
    for _, pid in ipairs(sorted_pids) do
        local process = processes[pid]
        local status = "inactive"
        if process.active and not process.completed then
            status = "active"
        elseif process.completed then
            status = "completed"
        end
        
        print(string.format("PID %d: %s [%s] (%s)", 
            pid, process.name, process.boot, status))
    end
    
    -- Pokaż następny dostępny PID
    print("Następny dostępny PID: " .. get_next_pid())
    print("==============================")
end

return pm
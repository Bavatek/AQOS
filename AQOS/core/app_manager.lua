local app_manager = {}
local pm = _G.system_pm

local APPS_DIR = "/AQOS/apps/"

-- Tworzenie katalogu aplikacji
if not fs.exists(APPS_DIR) then
    fs.makeDir(APPS_DIR)
end

function app_manager.install(name, from)
    local app_path = APPS_DIR .. name .. ".lua"
    
    -- Sprawdź czy aplikacja już istnieje
    if fs.exists(app_path) then
        print("Aplikacja '" .. name .. "' już istnieje!")
        return false
    end
    
    print("Instaluję '" .. name .. "'...")
    
    -- Sprawdź czy to kod pastebina (tylko litery/cyfry)
    if from:match("^[a-zA-Z0-9]+$") then
        -- Pastebin
        local success = shell.run("pastebin", "get", from, app_path)
        if success then
            print("Aplikacja zainstalowana z pastebina!")
            return true
        end
    else
        -- Lokalna ścieżka (może być z dysku)
        if fs.exists(from) then
            fs.copy(from, app_path)
            print("Aplikacja skopiowana!")
            return true
        else
            print("Błąd: Plik nie istnieje: " .. from)
        end
    end
    
    -- Cleanup przy błędzie
    if fs.exists(app_path) then
        fs.delete(app_path)
    end
    print("Błąd instalacji!")
    return false
end

function app_manager.run(name, mode)
    mode = mode or "tab"
    local app_path = APPS_DIR .. name .. ".lua"
    
    if not fs.exists(app_path) then
        print("Aplikacja '" .. name .. "' nie jest zainstalowana")
        return false
    end
    
    -- Jeśli tryb full, zatrzymaj terminal PRZED uruchomieniem aplikacji
    if mode == "full" then
        local terminal_process = pm.find_process("terminal")
        if terminal_process and terminal_process.active then
            terminal_process.active = false
            terminal_process.completed = false  -- Ważne! Nie usuwaj z pamięci
            print("Terminal zatrzymany dla aplikacji full...")
        end
    end
    
    -- Zarejestruj proces
    pm.ps_register(name, app_path)
    
    -- Uruchom w wybranym trybie
    local success = false
    if mode == "tab" then
        success = pm.ps_tab(name)
    elseif mode == "full" then
        success = pm.ps_full(name)
    elseif mode == "daemon" then
        success = pm.ps_daemon(name)
    end
    
    if success then
        print("Uruchomiono '" .. name .. "' w trybie " .. mode)
    else
        print("Błąd uruchomienia: " .. name)
    end
    
    return success
end

function app_manager.close(name)
    -- Zabij proces (usuwa z pamięci)
    if pm.ps_kill(name) then
        print("Zamknięto: " .. name)
        return true
    else
        print("Nie można zamknąć: " .. name)
        return false
    end
end

function app_manager.stop(name)
    -- Zatrzymaj proces (zawieś)
    if pm.ps_stop(name) then
        print("Zatrzymano: " .. name)
        return true
    else
        print("Nie można zatrzymać: " .. name)
        return false
    end
end

function app_manager.list()
    local files = fs.list(APPS_DIR)
    print("Aplikacje:")
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            print("  " .. file:gsub("%.lua$", ""))
        end
    end
end

function app_manager.uninstall(name)
    local app_path = APPS_DIR .. name .. ".lua"
    if fs.exists(app_path) then
        -- Najpierw zamknij proces jeśli działa
        pm.ps_kill(name)
        -- Usuń plik
        fs.delete(app_path)
        print("Usunięto: " .. name)
        return true
    end
    print("Nie znaleziono: " .. name)
    return false
end

return app_manager
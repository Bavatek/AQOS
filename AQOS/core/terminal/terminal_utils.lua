--terminal_utils.lua

local utils = {}
local pm = nil

-- Definicje komend
local COMMANDS = {
    native = {
        "ls", "dir", "cd", "cat", "type", "cp", "copy", "mv", "move", 
        "rm", "delete", "mkdir", "md", "find", "ping", "wget", "pastebin", 
        "id", "label", "time", "date", "programs", "edit", "lua", "which", 
        "alias", "redstone", "monitor", "disk", "mount", "startup"
    },
    aqos = {"ps", "stop", "kill", "status", "run"},
    replacements = {"clear", "reboot", "shutdown", "help"}
}

-- Wszystkie dostępne komendy
local all_commands = {}

-- ===== INICJALIZACJA =====

function utils.init(process_manager)
    pm = process_manager
    utils.build_command_list()
end

function utils.build_command_list()
    all_commands = {}
    for category, commands in pairs(COMMANDS) do
        for _, cmd in pairs(commands) do
            table.insert(all_commands, cmd)
        end
    end
end

function utils.draw_prompt(input_line)
    term.setCursorPos(1, select(2, term.getCursorPos()))
    term.clearLine()
    
    if term.isColor() then
        term.setTextColor(colors.lime)
    end
    term.write("> ")
    
    if term.isColor() then
        term.setTextColor(colors.white)
    end
    
    local prompt_text = input_line or ""
    term.write(prompt_text)
    term.setCursorBlink(true)
end

-- ===== KOMENDY =====

function utils.complete_command(input)
    if not input or input == "" then return input end
    
    local words = {}
    for word in input:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 0 then return input end
    
    local partial = words[1]
    local matches = {}
    
    for _, cmd in pairs(all_commands) do
        if cmd:sub(1, #partial) == partial and cmd ~= partial then
            table.insert(matches, cmd)
        end
    end
    
    if #matches == 1 then
        words[1] = matches[1]
        return table.concat(words, " ")
    elseif #matches > 1 then
        local common_prefix = matches[1]
        for i = 2, #matches do
            local match = matches[i]
            local j = 1
            while j <= #common_prefix and j <= #match and 
                  common_prefix:sub(j, j) == match:sub(j, j) do
                j = j + 1
            end
            common_prefix = common_prefix:sub(1, j - 1)
        end
        
        if #common_prefix > #partial then
            words[1] = common_prefix
            return table.concat(words, " ")
        end
    end
    
    return input
end

function utils.execute_command(input)
    if not input or input == "" then return end
    
    local parts = {}
    for word in input:gmatch("%S+") do
        table.insert(parts, word)
    end
    
    local command = parts[1]
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    if utils.is_command_type(command, "replacements") then
        utils.execute_aqos_replacement(command, args)
    elseif utils.is_command_type(command, "aqos") then
        utils.execute_aqos_command(command, args)
    elseif utils.is_command_type(command, "native") then
        utils.execute_native_command(command, args)
    else
        printError("Komenda '" .. command .. "' nie jest dozwolona w AQOS")
    end
end

function utils.is_command_type(command, type)
    if not COMMANDS[type] then return false end
    
    for _, cmd in pairs(COMMANDS[type]) do
        if cmd == command then return true end
    end
    return false
end

-- ===== KOMENDY AQOS =====

function utils.execute_aqos_replacement(command, args)
    if command == "clear" then
        term.clear()
        term.setCursorPos(1, 1)
        print("Terminal wyczyszczony")
        
    elseif command == "reboot" then
        print("Restartowanie systemu AQOS...")
        if pm and pm.ps_stop_monitor then pm.ps_stop_monitor() end
        sleep(1)
        os.reboot()
        
    elseif command == "shutdown" then
        print("Zamykanie systemu AQOS...")
        if pm and pm.ps_stop_monitor then pm.ps_stop_monitor() end
        sleep(1)
        os.shutdown()
        
    elseif command == "help" then
        utils.show_help(args[1])
    end
end

function utils.execute_aqos_command(command, args)
    if command == "ps" then
        utils.show_processes()
        
            elseif command == "run" then
        if #args < 1 then
            printError("Uzycie: run <aplikacja> [daemon/tab] [sciezka]")
        else
            utils.run_app(args[1], args[2], args[3])
        end
        
    elseif command == "stop" then
        if #args < 1 then
            printError("Uzycie: stop <nazwa_lub_pid>")
        else
            utils.stop_process(args[1])
        end
        
    elseif command == "kill" then
        if #args < 1 then
            printError("Uzycie: kill <nazwa_lub_pid>")
        else
            utils.kill_process(args[1])
        end
        
    elseif command == "status" then
        if #args < 1 then
            printError("Uzycie: status <nazwa_lub_pid>")
        else
            utils.show_process_status(args[1])
        end
    end
end

function utils.execute_native_command(command, args)
    local success = pcall(function()
        if #args > 0 then
            local full_command = command .. " " .. table.concat(args, " ")
            shell.run(full_command)
        else
            shell.run(command)
        end
    end)
    
    if not success then
        printError("Komenda zwrocila blad lub nie znaleziono: " .. command)
    end
end

-- ===== APLIKACJE =====

function utils.find_app_path(name, custom_path)
    if not name or name == "" then return nil end
    
    -- Jeśli podano niestandardową ścieżkę
    if custom_path and custom_path ~= "" then
        if fs.exists(custom_path) then return custom_path end
        
        -- Spróbuj z .lua
        local path_with_lua = custom_path .. ".lua"
        if fs.exists(path_with_lua) then return path_with_lua end
        
        return nil
    end
    
    -- DOMYŚLNIE: AQOS/apps z .lua
    local path = "AQOS/apps/" .. name .. ".lua"
    if fs.exists(path) then return path end
    
    -- DOMYŚLNIE: AQOS/apps bez .lua
    path = "AQOS/apps/" .. name
    if fs.exists(path) then return path end
    
    -- Fallback: Pełna ścieżka
    if fs.exists(name) then return name end
    
    -- Fallback: Bieżący katalog
    path = shell.dir() .. "/" .. name
    if fs.exists(path) then return path end
    
    -- Fallback: Bieżący katalog z .lua
    path = shell.dir() .. "/" .. name .. ".lua"
    if fs.exists(path) then return path end
    
    return nil
end

function utils.run_app(app_name, boot_type, custom_path)
    local app_path = utils.find_app_path(app_name, custom_path)
    if not app_path then
        printError("Nie znaleziono aplikacji: " .. app_name)
        if custom_path then
            print("Sprawdz niestandardowa sciezke: " .. custom_path)
        else
            print("Sprawdz folder: AQOS/apps/")
        end
        return
    end
    
    if not pm then
        printError("Process Manager niedostepny")
        return
    end
    
    -- Znajdź unikalną nazwę procesu
    local process_name = utils.get_unique_process_name(app_name)
    
    -- Zarejestruj proces
    local pid = pm.ps_register(process_name)
    
    -- Określ tryb uruchomienia
    if boot_type == "daemon" then
        utils.run_as_daemon(process_name, app_name, app_path)
    elseif boot_type == "tab" then
        utils.run_as_tab(process_name, app_name, app_path)
    else
        utils.run_as_fullscreen(process_name, app_name, app_path)
    end
end

function utils.get_unique_process_name(app_name)
    if not pm or not pm.ps_list then
        return app_name
    end
    
    local processes = pm.ps_list()
    local existing_names = {}
    
    -- Zbierz wszystkie istniejące nazwy procesów
    for pid, process in pairs(processes) do
        existing_names[process.name] = true
    end
    
    -- Sprawdź czy podstawowa nazwa jest dostępna
    if not existing_names[app_name] then
        return app_name
    end
    
    -- Znajdź najniższy dostępny numer
    local counter = 1
    while existing_names[app_name .. "_" .. counter] do
        counter = counter + 1
    end
    
    return app_name .. "_" .. counter
end

function utils.run_as_fullscreen(process_name, app_name, app_path)
    pm.ps_app(process_name, false, app_path)
    
    print("Uruchamianie: " .. app_name .. " (fullscreen)")
    
    -- Sprawdź czy plik istnieje przed uruchomieniem
    if not fs.exists(app_path) then
        printError("Plik nie istnieje: " .. app_path)
        if pm.ps_kill then
            pm.ps_kill(process_name)
        end
        return
    end
    
    -- Uruchom aplikację przez os.run
    local run_success = pcall(function()
        os.run({}, app_path)
    end)
    
    if run_success then
        print("Aplikacja zakonczona: " .. app_name)
    else
        printError("BLAD aplikacji: " .. app_name)
    end
    
    -- Usuń proces
    if pm.ps_kill then
        pm.ps_kill(process_name)
    end
end

function utils.run_as_daemon(process_name, app_name, app_path)
    local result = pm.ps_app(process_name, true, app_path)
    
    if result then
        print("Daemon uruchomiony: " .. app_name)
        print("Nazwa procesu: " .. process_name)
    else
        printError("BLAD uruchamiania daemon: " .. app_name)
        pm.ps_kill(process_name)
    end
end

function utils.run_as_tab(process_name, app_name, app_path)
    local result = pm.ps_tab(process_name, app_path)
    
    if result then
        print("Tab uruchomiony: " .. app_name)
        print("Nazwa procesu: " .. process_name)
    else
        printError("BLAD uruchamiania tab: " .. app_name)
        pm.ps_kill(process_name)
    end
end

-- ===== PROCESY =====

function utils.stop_process(name)
    if not pm then
        printError("Process Manager niedostepny")
        return
    end
    
    local result = pm.ps_state(name, "inactive")
    
    if result then
        print("Zatrzymano proces: " .. name)
    else
        printError("Nie znaleziono procesu: " .. name)
    end
end

function utils.kill_process(name)
    if not pm then
        printError("Process Manager niedostepny")
        return
    end
    
    local result = pm.ps_kill(name)
    
    if result then
        print("Usunieto proces: " .. name)
    else
        printError("Nie znaleziono procesu: " .. name)
    end
end

function utils.show_processes()
    if not pm or not pm.ps_list then
        printError("Process Manager niedostepny")
        return
    end
    
    local processes = pm.ps_list()
    
    print("=== LISTA PROCESOW AQOS ===")
    print("PID  NAZWA           TYP           STATUS")
    print("----------------------------------------")
    
    for pid, process in pairs(processes) do
        local status = "nieaktywny"
        
        if process.active and not process.completed then
            status = "aktywny"
        elseif process.completed then
            status = "zakonczony"
        end
        
        local line = string.format("%-4d %-15s %-13s %s", 
            pid, process.name or "unknown", process.boot or "-", status)
        print(line)
    end
end

function utils.show_process_status(name)
    if not pm then
        printError("Process Manager niedostepny")
        return
    end
    
    local process = pm.ps_status(name)
    
    if process then
        print("=== STATUS PROCESU ===")
        print("PID: " .. (process.pid or "unknown"))
        print("Nazwa: " .. (process.name or "unknown"))
        print("Typ: " .. (process.boot or "-"))
        print("Aktywny: " .. tostring(process.active))
        print("Zakonczony: " .. tostring(process.completed))
        print("Daemon: " .. tostring(process.daemon))
        
        if process.app_path and type(process.app_path) == "string" then
            print("Sciezka: " .. process.app_path)
        end
        if process.tab_id then
            print("Tab ID: " .. process.tab_id)
        end
    else
        printError("Nie znaleziono procesu: " .. name)
    end
end

-- ===== POMOC =====

function utils.show_help(command)
    if command then
        utils.show_command_help(command)
    else
        utils.show_general_help()
    end
end

function utils.show_general_help()
    print("=== POMOC AQOS TERMINAL ===")
    print("")
    print("Komendy CraftOS:")
    print("  ls/dir, cd, cat/type   - pliki i katalogi")
    print("  cp/copy, mv/move, rm   - operacje na plikach")
    print("  edit, lua, programs    - edycja i programowanie")
    print("  ping, wget, pastebin   - siec i internet")
    print("  time, date, label, id  - system i info")
    print("")
    print("Komendy AQOS:")
    print("  ps                     - lista procesow")
    print("  run <app>              - uruchom z AQOS/apps/")
    print("  run <app> daemon       - uruchom w tle")
    print("  run <app> tab          - uruchom w tab")
    print("  run <app> <typ> <path> - niestandardowa sciezka")
    print("  stop/kill <nazwa>      - zatrzymaj/usun proces")
    print("  clear                  - wyczysc ekran")
    print("")
    print("Skroty klawiszowe:")
    print("  Tab                    - dopelnianie komend")
end

function utils.show_command_help(command)
    print("=== POMOC: " .. string.upper(command) .. " ===")
    
    if command == "run" then
        print("Uruchamia aplikacje w roznych trybach")
        print("Uzycie:")
        print("  run <app>              - z AQOS/apps/ (fullscreen)")
        print("  run <app> daemon       - w tle")
        print("  run <app> tab          - w tab")
        print("  run <app> <typ> <path> - niestandardowa sciezka")
        print("Domyslnie szuka w folderze AQOS/apps/")
        print("Zawsze rejestruje proces w PM")
        
    elseif command == "ps" then
        print("Wyswietla liste procesow AQOS")
        print("Uzycie: ps")
        print("Pokazuje PID, nazwe, typ i status")
        
    elseif command == "stop" then
        print("Zatrzymuje proces (nie usuwa)")
        print("Uzycie: stop <nazwa_lub_pid>")
        
    elseif command == "kill" then
        print("Usuwa proces z systemu")
        print("Uzycie: kill <nazwa_lub_pid>")
        
    else
        printError("Nieznana komenda: " .. command)
        print("Wpisz 'help' aby zobaczyc dostepne komendy")
    end
end

return utils
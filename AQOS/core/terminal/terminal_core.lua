--terminal_core.lua

local utils = require(".AQOS/core/terminal/terminal_utils")

local terminal = {}
local running = false
local input_line = ""

-- Walidacja zależności systemu
local function validate_dependencies()
    if not _G.system_pm then
        print("BLAD: Process Manager niedostepny")
        return false
    end
    
    if not _G.system_eh then
        print("BLAD: Event Handler niedostepny")
        return false
    end
    
    return true
end

-- Inicjalizacja terminala
function terminal.init()
    if not validate_dependencies() then
        return false
    end
    
    local success = pcall(function()
        utils.init(_G.system_pm)
        print("System AQOS uruchomiony")
        print("Wpisz 'help' aby zobaczyc dostepne komendy")
        utils.draw_prompt("")
    end)
    
    if not success then
        print("BLAD inicjalizacji terminala")
        return false
    end
    
    return true
end

-- Główna pętla terminala
function terminal.main()
    if not terminal.init() then
        return
    end
    
    running = true
    
    while running do
        local success = pcall(function()
            terminal.handle_events()
        end)
        
        if not success then
            print("Terminal odzyskuje dzialanie...")
            utils.draw_prompt(input_line)
            sleep(0.5)
        end
        
        sleep(0)
    end
end

-- Obsługa wszystkich eventów
function terminal.handle_events()
    local eh = _G.system_eh
    if not eh or not eh.get_event then
        sleep(0.1)
        return
    end
    
    -- Obsługa klawiatury
    local keyboard_event = eh.get_event("keyboard")
    if keyboard_event then
        terminal.handle_keyboard(keyboard_event)
    end
end

-- Obsługa eventów klawiatury
function terminal.handle_keyboard(event_data)
    if not event_data or #event_data < 2 then return end
    
    local event_name = event_data[1]
    local param = event_data[2]
    
    if event_name == "char" then
        terminal.add_char(param)
    elseif event_name == "key" then
        terminal.handle_key(param)
    end
end

-- Dodawanie znaku do linii wprowadzania
function terminal.add_char(char)
    if char and type(char) == "string" then
        input_line = (input_line or "") .. char
        utils.draw_prompt(input_line)
    end
end

-- Obsługa klawiszy specjalnych
function terminal.handle_key(key)
    if key == keys.enter then
        terminal.execute_command()
        
    elseif key == keys.backspace then
        terminal.remove_char()
        
    elseif key == keys.tab then
        terminal.complete_command()
    end
end

-- Wykonanie komendy
function terminal.execute_command()
    if not input_line or input_line == "" then
        utils.draw_prompt("")
        return
    end
    
    local command = input_line
    print("> " .. command)
    
    local success = pcall(function()
        utils.execute_command(command)
    end)
    
    if not success then
        printError("BLAD wykonania komendy")
    end
    
    input_line = ""
    utils.draw_prompt("")
end

-- Usuwanie znaku z linii wprowadzania
function terminal.remove_char()
    if input_line and #input_line > 0 then
        input_line = input_line:sub(1, -2)
        utils.draw_prompt(input_line)
    end
end

-- Autocompletowanie komend
function terminal.complete_command()
    if not input_line then return end
    
    local completed = utils.complete_command(input_line)
    if completed and completed ~= input_line then
        input_line = completed
        utils.draw_prompt(input_line)
    end
end

function terminal.stop()
    running = false
    print("Terminal zatrzymany")
end

return terminal
-- AQOS Startup - prosty system bootowania

term.clear()
term.setCursorPos(1, 1)

local GITHUB_BASE = "https://raw.githubusercontent.com/Bavatek/AQOS/main/"

-- Lista wymaganych plików
local files = {
    "AQOS/core/kernel.lua",
    "AQOS/core/terminal/terminal_core.lua", 
    "AQOS/core/terminal/terminal_utils.lua",
    "AQOS/core/app_manager.lua",
    "AQOS/core/event_handler.lua",
    "AQOS/core/process_manager.lua",
    "AQOS/version.txt"
}

-- Pobierz plik
local function download(file)
    print("Downloading: " .. file)
    local response = http.get(GITHUB_BASE .. file)
    if response then
        local content = response.readAll()
        response.close()
        
        -- Utworz folder jesli nie istnieje
        local dir = file:match("(.+)/[^/]+$")
        if dir and not fs.exists(dir) then
            fs.makeDir(dir)
        end
        
        local f = fs.open(file, "w")
        f.write(content)
        f.close()
        return true
    end
    return false
end

-- Sprawdz wersje
local function check_version()
    if fs.exists("AQOS/version.txt") then
        local f = fs.open("AQOS/version.txt", "r")
        local local_ver = f.readAll()
        f.close()
        
        local response = http.get(GITHUB_BASE .. "AQOS/version.txt")
        if response then
            local remote_ver = response.readAll()
            response.close()
            return local_ver == remote_ver
        end
    end
    return false
end

print("=== AQOS Boot ===")

-- Sprawdz HTTP
if not http then
    print("ERROR: Enable HTTP API")
    return
end

-- Sprawdz wersje lub pobierz brakujace pliki
if not check_version() then
    print("Downloading files...")
    for _, file in ipairs(files) do
        if not fs.exists(file) or file == "AQOS/version.txt" then
            if not download(file) then
                print("ERROR: " .. file)
                return
            end
        end
    end
end

-- Przejdz do folderu core i uruchom kernel
print("Starting AQOS...")
sleep(0.5)
shell.setDir("AQOS/core")
shell.run("kernel.lua")

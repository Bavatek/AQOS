-- AQOS Startup - prosty system bootowania
-- Zgodnie z filozofią: minimalizm, czytelność, prostota

local GITHUB_BASE = "https://raw.githubusercontent.com/twoj-username/aqos/main/"
local CURRENT_VERSION = "1.0.0"

-- Lista wymaganych plików w folderze core
local required_files = {
    "AQOS/core/kernel.lua",
    "AQOS/core/terminal/terminal_core.lua",
    "AQOS/core/terminal/terminal_utils.lua",
    "AQOS/core/app_manager.lua",
    "AQOS/core/event_handler.lua",
    "AQOS/core/process_manager.lua"
}

-- Funkcja sprawdzająca czy plik istnieje
local function file_exists(path)
    return fs.exists(path) and not fs.isDir(path)
end

-- Funkcja tworząca potrzebne foldery
local function create_directories()
    if not fs.exists("AQOS") then
        fs.makeDir("AQOS")
    end
    if not fs.exists("AQOS/core") then
        fs.makeDir("AQOS/core")
    end
    if not fs.exists("AQOS/core/terminal") then
        fs.makeDir("AQOS/core/terminal")
    end
    if not fs.exists("AQOS/apps") then
        fs.makeDir("AQOS/apps")
    end
end

-- Funkcja pobierająca plik z internetu
local function download_file(url, path)
    print("Pobieranie: " .. path)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(path, "w")
        file.write(content)
        file.close()
        return true
    else
        print("Błąd pobierania: " .. path)
        return false
    end
end

-- Funkcja sprawdzająca wersję
local function check_version()
    if file_exists("AQOS/version.txt") then
        local file = fs.open("AQOS/version.txt", "r")
        local local_version = file.readAll()
        file.close()
        
        local response = http.get(GITHUB_BASE .. "AQOS/version.txt")
        if response then
            local remote_version = response.readAll()
            response.close()
            
            if local_version ~= remote_version then
                print("Dostępna nowa wersja: " .. remote_version)
                return false
            else
                print("Wersja aktualna: " .. local_version)
                return true
            end
        end
    end
    return false
end

-- Funkcja sprawdzająca i pobierająca brakujące pliki
local function check_and_download_files()
    local missing_files = {}
    
    -- Sprawdź które pliki brakują
    for _, file_path in ipairs(required_files) do
        if not file_exists(file_path) then
            table.insert(missing_files, file_path)
        end
    end
    
    -- Pobierz brakujące pliki
    if #missing_files > 0 then
        print("Brakuje " .. #missing_files .. " plików. Pobieranie...")
        
        for _, file_path in ipairs(missing_files) do
            local url = GITHUB_BASE .. file_path
            if not download_file(url, file_path) then
                print("BŁĄD: Nie można pobrać " .. file_path)
                return false
            end
        end
        
        -- Pobierz też plik wersji
        download_file(GITHUB_BASE .. "AQOS/version.txt", "AQOS/version.txt")
    end
    
    return true
end

-- Główna funkcja bootowania
local function boot()
    print("=== AQOS Boot Manager ===")
    print("Sprawdzanie systemu...")
    
    -- Sprawdź połączenie internetowe
    if not http then
        print("BŁĄD: Brak dostępu do HTTP")
        print("Włącz http API w konfiguracji")
        return false
    end
    
    -- Utwórz potrzebne foldery
    create_directories()
    
    -- Sprawdź wersję i pliki
    local version_ok = check_version()
    
    if not version_ok then
        print("Aktualizacja wymagana...")
        if not check_and_download_files() then
            print("BŁĄD: Nie można zaktualizować systemu")
            return false
        end
    end
    
    -- Sprawdź jeszcze raz czy wszystkie pliki są na miejscu
    if not check_and_download_files() then
        print("BŁĄD: Brakuje plików systemowych")
        return false
    end
    
    print("System gotowy. Uruchamianie kernela...")
    return true
end

-- Uruchom boot i kernel
if boot() then
    sleep(1)
    os.run({}, "AQOS/core/kernel.lua")
else
    print("Boot nieudany. Sprawdź połączenie i spróbuj ponownie.")
end
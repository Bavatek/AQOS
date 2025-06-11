-- główny skrypt uruchomieniowy systemu, kernel.lua

-- Załaduj moduły systemu
_G.system_pm = require("./AQOS/core/process_manager")
_G.system_eh = require("./AQOS/core/event_handler")
local pm = _G.system_pm
local eh = _G.system_eh 
local terminal = require("./AQOS/core/terminal/terminal_core")

if not pm or not eh then
    term.clear()
    term.setCursorPos(1,1)
    print("BŁĄD_KRYTYCZNY: Nie można załadować PM lub EH")
    term.setCursorPos(1,2)
    term.setCursorBlink(true)
    sleep(10)
    return false
end

-- Rejestracja procesów systemowych
print("AQOS Kernel uruchomiony")
print("Rejestrowanie procesów systemowych...")

pm.ps_register("event_handler")  
pm.ps_register("terminal")

-- Uruchom event_handler (pełny dostęp do eventów z pullEventRaw)
local eh_success = pm.ps_event_handler("event_handler", eh.start)
if not eh_success then
    print("BŁĄD: Nie udało się uruchomić Event Handler")
    return false
end

-- Uruchom terminal (może być terminowany)
local terminal_success = pm.ps_system("terminal", terminal.main)
if not terminal_success then
    print("BŁĄD: Nie udało się uruchomić Terminal")
    return false
end

-- Debug - sprawdź procesy
print("=== PROCESY SYSTEMOWE ===")
pm.ps_debug()
sleep(2)

print("Uruchamianie Process Monitor...")

-- Start monitora - to będzie główna pętla systemu
pm.ps_monitor()

-- Jeśli dotarliśmy tutaj, system się zakończył
print("Kernel zakończony")
os.shutdown()
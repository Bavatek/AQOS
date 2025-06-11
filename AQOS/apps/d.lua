-- test_daemon.lua - prosty daemon do testowania
print("=== TEST DAEMON STARTUJE ===")

local counter = 0
local start_time = os.clock()
local log_file = "daemon_log.txt"

-- Funkcja pisania logu
local function write_log(message)
    local file = fs.open(log_file, "a")
    if file then
        local timestamp = string.format("%.1f", os.clock() - start_time)
        file.writeLine("[" .. timestamp .. "s] " .. message)
        file.close()
    end
end

-- Inicjalizacja
write_log("Daemon uruchomiony!")
print("Daemon pisze logi do: " .. log_file)

-- Główna pętla daemon
while true do
    local event, param1, param2 = os.pullEvent()
    
    if event == "terminate" then
        write_log("Otrzymano TERMINATE - wyłączam się")
        print("Daemon otrzymał terminate - kończę")
        break
        
    elseif event == "timer" then
        counter = counter + 1
        local uptime = string.format("%.1f", os.clock() - start_time)
        write_log("Timer #" .. counter .. " (uptime: " .. uptime .. "s)")
        
        -- Ustaw kolejny timer za 3 sekundy
        os.startTimer(3)
        
    elseif event == "key" then
        write_log("Ktoś nacisnął klawisz: " .. (param1 or "unknown"))
        
    elseif event == "char" then
        write_log("Wpisano znak: " .. (param1 or "unknown"))
    end
    sleep(1)
end

-- Cleanup
write_log("Daemon zakończony po " .. string.format("%.1f", os.clock() - start_time) .. " sekundach")
print("=== TEST DAEMON ZAKOŃCZONY ===")
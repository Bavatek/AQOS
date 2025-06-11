-- Prosty kalkulator klikany dla CC:Tweaked
local w, h = term.getSize()

local display = "0"
local operator = nil
local prev_num = nil
local new_input = true

-- Funkcje kalkulatora
local function calculate(a, op, b)
    if op == "+" then
        return a + b
    elseif op == "-" then
        return a - b
    elseif op == "*" then
        return a * b
    elseif op == "/" then
        if b == 0 then
            return "ERROR"
        end
        return a / b
    end
end

-- Rysowanie interfejsu
local function draw_button(x, y, width, height, text, bg_color, text_color)
    bg_color = bg_color or colors.lightGray
    text_color = text_color or colors.black
    
    term.setBackgroundColor(bg_color)
    term.setTextColor(text_color)
    
    for row = y, y + height - 1 do
        term.setCursorPos(x, row)
        term.write(string.rep(" ", width))
    end
    
    -- Wyśrodkuj tekst
    local text_x = x + math.floor((width - #text) / 2)
    local text_y = y + math.floor(height / 2)
    term.setCursorPos(text_x, text_y)
    term.write(text)
end

local function draw_display()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(2, 2)
    term.write(string.rep(" ", w - 2))
    
    -- Wyświetl liczbę z prawej strony
    local display_text = tostring(display)
    if #display_text > w - 4 then
        display_text = string.sub(display_text, 1, w - 4)
    end
    
    term.setCursorPos(w - #display_text - 1, 2)
    term.write(display_text)
end

local function draw_calculator()
    term.setBackgroundColor(colors.gray)
    term.clear()
    
    -- Tytuł
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.write(string.rep(" ", w))
    term.setCursorPos(math.floor((w - 10) / 2), 1)
    term.write("KALKULATOR")
    
    -- Wyświetlacz
    draw_display()
    
    -- Przyciski (4x4 siatka)
    local buttons = {
        {"C", "+/-", "%", "/"},
        {"7", "8", "9", "*"},
        {"4", "5", "6", "-"},
        {"1", "2", "3", "+"},
        {"0", ".", "=", "="}
    }
    
    local button_width = 4
    local button_height = 2
    local start_x = 2
    local start_y = 4
    
    for row = 1, #buttons do
        for col = 1, #buttons[row] do
            local x = start_x + (col - 1) * (button_width + 1)
            local y = start_y + (row - 1) * (button_height + 1)
            
            local text = buttons[row][col]
            local bg_color = colors.lightGray
            
            -- Kolorowanie specjalnych przycisków
            if text == "=" then
                bg_color = colors.orange
            elseif text == "C" or text == "+/-" or text == "%" then
                bg_color = colors.red
            elseif text == "+" or text == "-" or text == "*" or text == "/" then
                bg_color = colors.blue
            end
            
            -- Szeroki przycisk "0"
            if text == "0" then
                draw_button(x, y, button_width * 2 + 1, button_height, text, bg_color, colors.white)
            elseif col < 4 or text ~= "=" then -- Nie rysuj drugiego "="
                draw_button(x, y, button_width, button_height, text, bg_color, colors.white)
            end
        end
    end
end

-- Obsługa przycisków
local function handle_number(num)
    if new_input then
        display = num
        new_input = false
    else
        if display == "0" then
            display = num
        else
            display = display .. num
        end
    end
end

local function handle_operator(op)
    if operator and not new_input then
        -- Wykonaj poprzednią operację
        local result = calculate(prev_num, operator, tonumber(display))
        display = tostring(result)
    end
    
    prev_num = tonumber(display)
    operator = op
    new_input = true
end

local function handle_equals()
    if operator and prev_num then
        local result = calculate(prev_num, operator, tonumber(display))
        display = tostring(result)
        operator = nil
        prev_num = nil
        new_input = true
    end
end

local function handle_clear()
    display = "0"
    operator = nil
    prev_num = nil
    new_input = true
end

local function get_button_at(x, y)
    local buttons = {
        {"C", "+/-", "%", "/"},
        {"7", "8", "9", "*"},
        {"4", "5", "6", "-"},
        {"1", "2", "3", "+"},
        {"0", ".", "=", "="}
    }
    
    local button_width = 4
    local button_height = 2
    local start_x = 2
    local start_y = 4
    
    for row = 1, #buttons do
        for col = 1, #buttons[row] do
            local btn_x = start_x + (col - 1) * (button_width + 1)
            local btn_y = start_y + (row - 1) * (button_height + 1)
            
            local btn_w = button_width
            if buttons[row][col] == "0" then
                btn_w = button_width * 2 + 1
            end
            
            if x >= btn_x and x < btn_x + btn_w and y >= btn_y and y < btn_y + button_height then
                return buttons[row][col]
            end
        end
    end
    return nil
end

-- Główna pętla
local function main()
    draw_calculator()
    
    while true do
        local event, button, x, y = os.pullEvent()
        
        if event == "mouse_click" and button == 1 then
            local pressed_button = get_button_at(x, y)
            
            if pressed_button then
                -- Obsługa przycisków
                if tonumber(pressed_button) then
                    handle_number(pressed_button)
                elseif pressed_button == "." then
                    if not string.find(display, "%.") then
                        if new_input then
                            display = "0."
                            new_input = false
                        else
                            display = display .. "."
                        end
                    end
                elseif pressed_button == "C" then
                    handle_clear()
                elseif pressed_button == "=" then
                    handle_equals()
                elseif pressed_button == "+" or pressed_button == "-" or 
                       pressed_button == "*" or pressed_button == "/" then
                    handle_operator(pressed_button)
                elseif pressed_button == "+/-" then
                    local num = tonumber(display)
                    if num then
                        display = tostring(-num)
                    end
                elseif pressed_button == "%" then
                    local num = tonumber(display)
                    if num then
                        display = tostring(num / 100)
                    end
                end
                
                draw_calculator()
            end
        elseif event == "key" and button == keys.q then
            -- Wyjście przez Q
            break
        end
    end
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    print("Kalkulator zamkniety")
end

main()
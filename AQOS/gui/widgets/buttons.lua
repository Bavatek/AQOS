local events = require("./AQOS/core/event_handler")
local buttons = {}

function buttons.init(parent, x, y, w, h, text, color, textColor)
    local btn = {
        parent = parent or term.current(),
        x = x or 1,
        y = y or 1,
        width = w or 10,
        height = h or 3,
        text = text or "Button",
        color = color or "8",
        textColor = textColor or "0",
        visible = true
    }
    
    function btn:draw()
        if not self.visible then return end
        
        -- Cache stringów (poza pętlą)
        local lineText = string.rep(" ", self.width)
        local lineBg = string.rep(self.color, self.width)
        local lineTextColor = string.rep("0", self.width)
        local textBg = string.rep(self.color, #self.text)
        local textFg = string.rep(self.textColor, #self.text)
        
        -- Cache pozycji tekstu (poza pętlą)
        local textX = self.x + math.floor((self.width - #self.text) / 2)
        local textY = self.y + math.floor(self.height / 2)
        
        -- Rysuj tło przycisku
        for i = 0, self.height - 1 do
            self.parent.setCursorPos(self.x, self.y + i)
            self.parent.blit(lineText, lineTextColor, lineBg)
        end
        
        -- Rysuj tekst na środku
        self.parent.setCursorPos(textX, textY)
        self.parent.blit(self.text, textFg, textBg)
    end
    
    function btn:del()
        self.visible = false
    end
    
    function btn:onClick(eventType, callback)

    end
        
    return btn
end

return buttons

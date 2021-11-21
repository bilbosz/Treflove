TextInput = {}

local function CreateBackground(self)
    self.background = Rectangle(self, self.width, self.height, Consts.BUTTON_NORMAL_COLOR)
end

local function CreateCaret(self)
    self.caret = Rectangle(self, 3, self.height - 2 * self.padding, Consts.TEXT_INPUT_FOREGROUND_COLOR)
    self.caret:SetPosition(self.padding, self.padding)
end

function TextInput:Init(parent, width, height)
    Control.Init(self, parent)
    self.width = width
    self.height = height
    self.padding = 10
    CreateBackground(self)
    CreateCaret(self)
    app.updateEventManager:RegisterListener(self)
end

function TextInput:OnUpdate(dt)
    self.time = (self.time or 0) + dt
    self.caret:SetEnabled(math.fmod(self.time, 1) >= 0.5)
end

MakeClassOf(TextInput, Control, UpdateEventListener)

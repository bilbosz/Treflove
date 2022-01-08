Session = {}

function Session:Init(connection)
    self.connection = connection
    self.login = Login(self, function(user)
        self.user = user
        if app.isClient then
            app.logger:Log("Logged in as %s", user)
            app.screenManager:Pop()
        end
    end)
end

function Session:GetUser()
    return self.user
end

function Session:GetConnection()
    return self.connection
end

function Session:Release()
    self.login:Release()
    self.login = nil
    self.connection = nil
end

MakeClassOf(Session)

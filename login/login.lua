Login = {}

function Login:Init()
end

function Login:LogIn(id)
    app.logger:Log("Trying to log in as \"%s\"", id)
end

function Login:LogOut(id)
    app.logger:Log("Trying to log out as \"%s\"", id)
end

function Login.GetLoginId(user, password)
    return Hash(user .. string.char(0) .. GenerateSalt(32) .. string.char(0) .. password)
end

MakeClassOf(Login)

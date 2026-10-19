-- app/client.tlt: the client application, with the UI and every event
-- manager; it has one connection and one session (`App.session`, anchored
-- to its connection). Its quit back entry is anchored to it.
global interface Client is App
end

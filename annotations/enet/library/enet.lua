---@meta enet

---The `enet` module LÖVE bundles (lua-enet over ENet 1.3): reliable,
---sequenced packets over UDP between a host and its peers. Hand-written
---from LÖVE 11.5's binding (`src/libraries/enet/enet.cpp`); the LuaCATS
---organization has no package for it.
---@class enet
local enet = {}

---@alias enet.PacketFlag
---| "reliable" # Delivered, in order within its channel (the default)
---| "unreliable" # May be lost; the ones that arrive are sequenced
---| "unsequenced" # May be lost and arrive in any order

---@alias enet.PeerState
---| "disconnected"
---| "connecting"
---| "acknowledging_connect"
---| "connection_pending"
---| "connection_succeeded"
---| "connected"
---| "disconnect_later"
---| "disconnecting"
---| "acknowledging_disconnect"
---| "zombie"
---| "unknown"

---@alias enet.EventType
---| "connect" # A peer connected; `data` is the number it sent with its connect
---| "disconnect" # A peer disconnected, or a connection attempt timed out; `data` is the number sent with the disconnect
---| "receive" # A packet arrived; `data` is its bytes, `channel` the channel it came on
---| "none"

---What `host:service` and `host:check_events` return
---@class enet.event
---@field type enet.EventType
---@field peer enet.peer|nil The peer of the event; absent for `"none"`
---@field data string|number The packet of a `"receive"`, the number of a `"connect"` or a `"disconnect"`
---@field channel number|nil The channel of a `"receive"`

---Creates a host. With an address (`"host:port"`, `"*"` for any host or
---port) the host listens there; without one it only connects out.
---@param address string|nil
---@param peer_count number|nil The most peers at once, 64 by default
---@param channel_count number|nil Channels per peer, 1 by default
---@param in_bandwidth number|nil Bytes per second, 0 (unlimited) by default
---@param out_bandwidth number|nil Bytes per second, 0 (unlimited) by default
---@return enet.host|nil host `nil` when the address could not be bound
---@return string|nil error
function enet.host_create(address, peer_count, channel_count, in_bandwidth, out_bandwidth) end

---@return string version `"major.minor.patch"` of the linked ENet
function enet.linked_version() end

---A UDP socket with its peers; every call that sends or receives goes
---through `service` or `check_events` on the thread that owns the host
---@class enet.host
local host = {}

---Sends and receives, waiting up to `timeout` milliseconds for an event
---@param timeout number|nil Milliseconds; 0 (no wait) by default, an explicit `nil` raises
---@return enet.event|nil event The first event, `nil` when the wait ran out
function host:service(timeout) end

---The next event already received, without touching the socket
---@return enet.event|nil
function host:check_events() end

---Starts connecting to `address` (`"host:port"`); the connection is up
---at the `"connect"` event of the returned peer
---@param address string
---@param channel_count number|nil 1 by default
---@param data number|nil Delivered with the `"connect"` event on the other side, 0 by default
---@return enet.peer
function host:connect(address, channel_count, data) end

---Sends the queued packets now, without waiting for events
function host:flush() end

---Sends a packet to every connected peer
---@param data string
---@param channel number|nil 0 by default
---@param flag enet.PacketFlag|nil `"reliable"` by default
function host:broadcast(data, channel, flag) end

---@param limit number The most channels a peer may use
function host:channel_limit(limit) end

---@param limit number Bytes per second, in and out alike
function host:bandwidth_limit(limit) end

---@return boolean success
function host:compress_with_range_coder() end

---@return string address `"ip:port"` the host is bound to
function host:get_socket_address() end

---Disconnects nothing: drops the host and its socket at once; the peers
---time out on their side
function host:destroy() end

---@return number bytes
function host:total_sent_data() end

---@return number bytes
function host:total_received_data() end

---@return number milliseconds The host's clock at the last `service`
function host:service_time() end

---@return number count The size of the peer array, connected or not
function host:peer_count() end

---@param index number 1-based, as `peer:index()` gives it
---@return enet.peer
function host:get_peer(index) end

---A remote host, as seen by the host that connected to it or accepted it.
---The binding hands out one userdata per peer while something holds it,
---so a peer keys a table.
---@class enet.peer
local peer = {}

---Queues a packet for the peer; it goes out on the next `service` or `flush`
---@param data string
---@param channel number|nil 0 by default
---@param flag enet.PacketFlag|nil `"reliable"` by default
---@return number result 0 on success, negative when the packet was refused
function peer:send(data, channel, flag) end

---Asks the peer to disconnect; the `"disconnect"` event comes once it acknowledged
---@param data number|nil Delivered with the event on the other side, 0 by default
function peer:disconnect(data) end

---Disconnects at once; the other side may never hear of it
---@param data number|nil
function peer:disconnect_now(data) end

---Disconnects once every queued packet has gone out
---@param data number|nil
function peer:disconnect_later(data) end

---Forgets the peer at once, without a word to it
function peer:reset() end

function peer:ping() end

---A packet received outside of `service`, from the peer's queue
---@param channel number|nil 0 by default
---@return string|nil data
---@return number|nil channel
function peer:receive(channel) end

---@param interval number
---@param acceleration number
---@param deceleration number
function peer:throttle_configure(interval, acceleration, deceleration) end

---@param interval number|nil Milliseconds; set when given
---@return number interval
function peer:ping_interval(interval) end

---Sets the three timeouts (an omitted one is 0, ENet's default for it)
---@param limit number|nil A multiple of the round trip time
---@param minimum number|nil Milliseconds
---@param maximum number|nil Milliseconds
---@return number limit
---@return number minimum
---@return number maximum
function peer:timeout(limit, minimum, maximum) end

---@return number index 1-based slot in the host's peer array
function peer:index() end

---@return enet.PeerState
function peer:state() end

---@return number id Unique to this connection of the peer
function peer:connect_id() end

---@param rtt number|nil Milliseconds; set when given
---@return number rtt
function peer:round_trip_time(rtt) end

---@param rtt number|nil Milliseconds; set when given
---@return number rtt
function peer:last_round_trip_time(rtt) end

return enet

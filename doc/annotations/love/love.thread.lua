---@class love.thread
---Allows you to work with threads.
---
---Threads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited.
---
---All LOVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object on multiple threads at the same time.
---
---When a LoveThread is started, it only loads the love.thread module. Every other module has to be loaded with require.
local m = {}

-- region LoveChannel
---@class LoveChannel
---An object which can be used to send and receive data between different threads.
local LoveChannel = {}
---Clears all the messages in the LoveChannel queue.
function LoveChannel:clear()
end

---Retrieves the value of a LoveChannel message and removes it from the message queue.
---
---It waits until a message is in the queue then returns the message value.
---@return Variant
---@overload fun(timeout:number):Variant
function LoveChannel:demand()
end

---Retrieves the number of messages in the thread LoveChannel queue.
---@return number
function LoveChannel:getCount()
end

---Gets whether a pushed value has been popped or otherwise removed from the LoveChannel.
---@param id number @An id value previously returned by LoveChannel:push.
---@return boolean
function LoveChannel:hasRead(id)
end

---Retrieves the value of a LoveChannel message, but leaves it in the queue.
---
---It returns nil if there's no message in the queue.
---@return Variant
function LoveChannel:peek()
end

---Executes the specified function atomically with respect to this LoveChannel.
---
---Calling multiple methods in a row on the same LoveChannel is often useful. However if multiple Threads are calling this LoveChannel's methods at the same time, the different calls on each LoveThread might end up interleaved (e.g. one or more of the second thread's calls may happen in between the first thread's calls.)
---
---This method avoids that issue by making sure the LoveThread calling the method has exclusive access to the LoveChannel until the specified function has returned.
---@param func function @The function to call, the form of function(channel, arg1, arg2, ...) end. The LoveChannel is passed as the first argument to the function when it is called.
---@param arg1 any @Additional arguments that the given function will receive when it is called.
---@param ... any @Additional arguments that the given function will receive when it is called.
---@return any, any
function LoveChannel:performAtomic(func, arg1, ...)
end

---Retrieves the value of a LoveChannel message and removes it from the message queue.
---
---It returns nil if there are no messages in the queue.
---@return Variant
function LoveChannel:pop()
end

---Send a message to the thread LoveChannel.
---
---See Variant for the list of supported types.
---@param value Variant @The contents of the message.
---@return number
function LoveChannel:push(value)
end

---Send a message to the thread LoveChannel and wait for a thread to accept it.
---
---See Variant for the list of supported types.
---@param value Variant @The contents of the message.
---@return boolean
---@overload fun(value:Variant, timeout:number):boolean
function LoveChannel:supply(value)
end

-- endregion LoveChannel
-- region LoveThread
---@class LoveThread
---A LoveThread is a chunk of code that can run in parallel with other threads. LoveData can be sent between different threads with LoveChannel objects.
local LoveThread = {}
---Retrieves the error string from the thread if it produced an error.
---@return string
function LoveThread:getError()
end

---Returns whether the thread is currently running.
---
---Threads which are not running can be (re)started with LoveThread:start.
---@return boolean
function LoveThread:isRunning()
end

---Starts the thread.
---
---Beginning with version 0.9.0, threads can be restarted after they have completed their execution.
---@overload fun(arg1:Variant, arg2:Variant, ...:Variant):void
function LoveThread:start()
end

---Wait for a thread to finish.
---
---This call will block until the thread finishes.
function LoveThread:wait()
end

-- endregion LoveThread
---Creates or retrieves a named thread channel.
---@param name string @The name of the channel you want to create or retrieve.
---@return LoveChannel
function m.getChannel(name)
end

---Create a new unnamed thread channel.
---
---One use for them is to pass new unnamed channels to other threads via LoveChannel:push on a named channel.
---@return LoveChannel
function m.newChannel()
end

---Creates a new LoveThread from a filename, string or LoveFileData object containing Lua code.
---@param filename string @The name of the Lua file to use as the source.
---@return LoveThread
---@overload fun(fileData:LoveFileData):LoveThread
---@overload fun(codestring:string):LoveThread
function m.newThread(filename)
end

return m

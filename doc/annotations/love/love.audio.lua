---@class love.audio
---Provides an interface to create noise with the user's speakers.
local m = {}

-- region LoveRecordingDevice
---@class LoveRecordingDevice
---Represents an audio input device capable of recording sounds.
local LoveRecordingDevice = {}
---Gets the number of bits per sample in the data currently being recorded.
---@return number
function LoveRecordingDevice:getBitDepth()
end

---Gets the number of bits per sample in the data currently being recorded.
---@return number
function LoveRecordingDevice:getBitDepth()
end

---Gets the number of channels currently being recorded (mono or stereo).
---@return number
function LoveRecordingDevice:getChannelCount()
end

---Gets all recorded audio LoveSoundData stored in the device's internal ring buffer.
---
---The internal ring buffer is cleared when this function is called, so calling it again will only get audio recorded after the previous call. If the device's internal ring buffer completely fills up before getData is called, the oldest data that doesn't fit into the buffer will be lost.
---@return LoveSoundData
function LoveRecordingDevice:getData()
end

---Gets the name of the recording device.
---@return string
function LoveRecordingDevice:getName()
end

---Gets the number of currently recorded samples.
---@return number
function LoveRecordingDevice:getSampleCount()
end

---Gets the number of samples per second currently being recorded.
---@return number
function LoveRecordingDevice:getSampleRate()
end

---Gets whether the device is currently recording.
---@return boolean
function LoveRecordingDevice:isRecording()
end

---Begins recording audio using this device.
---@param samplecount number @The maximum number of samples to store in an internal ring buffer when recording. LoveRecordingDevice:getData clears the internal buffer when called.
---@param samplerate number @The number of samples per second to store when recording.
---@param bitdepth number @The number of bits per sample.
---@param channels number @Whether to record in mono or stereo. Most microphones don't support more than 1 channel.
---@return boolean
function LoveRecordingDevice:start(samplecount, samplerate, bitdepth, channels)
end

---Stops recording audio from this device. Any sound data currently in the device's buffer will be returned.
---@return LoveSoundData
function LoveRecordingDevice:stop()
end

-- endregion LoveRecordingDevice
-- region LoveSource
---@class LoveSource
---A LoveSource represents audio you can play back.
---
---You can do interesting things with Sources, like set the volume, pitch, and its position relative to the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources.
---
---The LoveSource controls (play/pause/stop) act according to the following state table.
local LoveSource = {}
---Creates an identical copy of the LoveSource in the stopped state.
---
---Static Sources will use significantly less memory and take much less time to be created if LoveSource:clone is used to create them instead of love.audio.newSource, so this method should be preferred when making multiple Sources which play the same sound.
---@return LoveSource
function LoveSource:clone()
end

---Gets a list of the LoveSource's active effect names.
---@return table
function LoveSource:getActiveEffects()
end

---Gets the amount of air absorption applied to the LoveSource.
---
---By default the value is set to 0 which means that air absorption effects are disabled. A value of 1 will apply high frequency attenuation to the LoveSource at a rate of 0.05 dB per meter.
---@return number
function LoveSource:getAirAbsorption()
end

---Gets the reference and maximum attenuation distances of the LoveSource. The values, combined with the current DistanceModel, affect how the LoveSource's volume attenuates based on distance from the listener.
---@return number, number
function LoveSource:getAttenuationDistances()
end

---Gets the number of channels in the LoveSource. Only 1-channel (mono) Sources can use directional and positional effects.
---@return number
function LoveSource:getChannelCount()
end

---Gets the LoveSource's directional volume cones. Together with LoveSource:setDirection, the cone angles allow for the LoveSource's volume to vary depending on its direction.
---@return number, number, number
function LoveSource:getCone()
end

---Gets the direction of the LoveSource.
---@return number, number, number
function LoveSource:getDirection()
end

---Gets the duration of the LoveSource. For streaming Sources it may not always be sample-accurate, and may return -1 if the duration cannot be determined at all.
---@param unit TimeUnit @The time unit for the return value.
---@return number
function LoveSource:getDuration(unit)
end

---Gets the filter settings associated to a specific effect.
---
---This function returns nil if the effect was applied with no filter settings associated to it.
---@param name string @The name of the effect.
---@param filtersettings table @An optional empty table that will be filled with the filter settings.
---@return table
function LoveSource:getEffect(name, filtersettings)
end

---Gets the filter settings currently applied to the LoveSource.
---@return table
function LoveSource:getFilter()
end

---Gets the number of free buffer slots in a queueable LoveSource. If the queueable LoveSource is playing, this value will increase up to the amount the LoveSource was created with. If the queueable LoveSource is stopped, it will process all of its internal buffers first, in which case this function will always return the amount it was created with.
---@return number
function LoveSource:getFreeBufferCount()
end

---Gets the current pitch of the LoveSource.
---@return number
function LoveSource:getPitch()
end

---Gets the position of the LoveSource.
---@return number, number, number
function LoveSource:getPosition()
end

---Returns the rolloff factor of the source.
---@return number
function LoveSource:getRolloff()
end

---Gets the type of the LoveSource.
---@return SourceType
function LoveSource:getType()
end

---Gets the velocity of the LoveSource.
---@return number, number, number
function LoveSource:getVelocity()
end

---Gets the current volume of the LoveSource.
---@return number
function LoveSource:getVolume()
end

---Returns the volume limits of the source.
---@return number, number
function LoveSource:getVolumeLimits()
end

---Returns whether the LoveSource will loop.
---@return boolean
function LoveSource:isLooping()
end

---Returns whether the LoveSource is playing.
---@return boolean
function LoveSource:isPlaying()
end

---Gets whether the LoveSource's position, velocity, direction, and cone angles are relative to the listener.
---@return boolean
function LoveSource:isRelative()
end

---Pauses the LoveSource.
function LoveSource:pause()
end

---Starts playing the LoveSource.
---@return boolean
function LoveSource:play()
end

---Queues LoveSoundData for playback in a queueable LoveSource.
---
---This method requires the LoveSource to be created via love.audio.newQueueableSource.
---@param sounddata LoveSoundData @The data to queue. The LoveSoundData's sample rate, bit depth, and channel count must match the LoveSource's.
---@return boolean
function LoveSource:queue(sounddata)
end

---Sets the currently playing position of the LoveSource.
---@param offset number @The position to seek to.
---@param unit TimeUnit @The unit of the position value.
function LoveSource:seek(offset, unit)
end

---Sets the amount of air absorption applied to the LoveSource.
---
---By default the value is set to 0 which means that air absorption effects are disabled. A value of 1 will apply high frequency attenuation to the LoveSource at a rate of 0.05 dB per meter.
---
---Air absorption can simulate sound transmission through foggy air, dry air, smoky atmosphere, etc. It can be used to simulate different atmospheric conditions within different locations in an area.
---@param amount number @The amount of air absorption applied to the LoveSource. Must be between 0 and 10.
function LoveSource:setAirAbsorption(amount)
end

---Sets the reference and maximum attenuation distances of the LoveSource. The parameters, combined with the current DistanceModel, affect how the LoveSource's volume attenuates based on distance.
---
---Distance attenuation is only applicable to Sources based on mono (rather than stereo) audio.
---@param ref number @The new reference attenuation distance. If the current DistanceModel is clamped, this is the minimum attenuation distance.
---@param max number @The new maximum attenuation distance.
function LoveSource:setAttenuationDistances(ref, max)
end

---Sets the LoveSource's directional volume cones. Together with LoveSource:setDirection, the cone angles allow for the LoveSource's volume to vary depending on its direction.
---@param innerAngle number @The inner angle from the LoveSource's direction, in radians. The LoveSource will play at normal volume if the listener is inside the cone defined by this angle.
---@param outerAngle number @The outer angle from the LoveSource's direction, in radians. The LoveSource will play at a volume between the normal and outer volumes, if the listener is in between the cones defined by the inner and outer angles.
---@param outerVolume number @The LoveSource's volume when the listener is outside both the inner and outer cone angles.
function LoveSource:setCone(innerAngle, outerAngle, outerVolume)
end

---Sets the direction vector of the LoveSource. A zero vector makes the source non-directional.
---@param x number @The X part of the direction vector.
---@param y number @The Y part of the direction vector.
---@param z number @The Z part of the direction vector.
function LoveSource:setDirection(x, y, z)
end

---Applies an audio effect to the LoveSource.
---
---The effect must have been previously defined using love.audio.setEffect.
---@param name string @The name of the effect previously set up with love.audio.setEffect.
---@param enable boolean @If false and the given effect name was previously enabled on this LoveSource, disables the effect.
---@return boolean
---@overload fun(name:string, filtersettings:table):boolean
function LoveSource:setEffect(name, enable)
end

---Sets a low-pass, high-pass, or band-pass filter to apply when playing the LoveSource.
---@param settings table @The filter settings to use for this LoveSource, with the following fields:
---@return boolean
function LoveSource:setFilter(settings)
end

---Sets whether the LoveSource should loop.
---@param loop boolean @True if the source should loop, false otherwise.
function LoveSource:setLooping(loop)
end

---Sets the pitch of the LoveSource.
---@param pitch number @Calculated with regard to 1 being the base pitch. Each reduction by 50 percent equals a pitch shift of -12 semitones (one octave reduction). Each doubling equals a pitch shift of 12 semitones (one octave increase). Zero is not a legal value.
function LoveSource:setPitch(pitch)
end

---Sets the position of the LoveSource. Please note that this only works for mono (i.e. non-stereo) sound files!
---@param x number @The X position of the LoveSource.
---@param y number @The Y position of the LoveSource.
---@param z number @The Z position of the LoveSource.
function LoveSource:setPosition(x, y, z)
end

---Sets whether the LoveSource's position, velocity, direction, and cone angles are relative to the listener, or absolute.
---
---By default, all sources are absolute and therefore relative to the origin of love's coordinate system 0, 0. Only absolute sources are affected by the position of the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources. 
---@param enable boolean @True to make the position, velocity, direction and cone angles relative to the listener, false to make them absolute.
function LoveSource:setRelative(enable)
end

---Sets the rolloff factor which affects the strength of the used distance attenuation.
---
---Extended information and detailed formulas can be found in the chapter '3.4. Attenuation By Distance' of OpenAL 1.1 specification.
---@param rolloff number @The new rolloff factor.
function LoveSource:setRolloff(rolloff)
end

---Sets the velocity of the LoveSource.
---
---This does '''not''' change the position of the LoveSource, but lets the application know how it has to calculate the doppler effect.
---@param x number @The X part of the velocity vector.
---@param y number @The Y part of the velocity vector.
---@param z number @The Z part of the velocity vector.
function LoveSource:setVelocity(x, y, z)
end

---Sets the current volume of the LoveSource.
---@param volume number @The volume for a LoveSource, where 1.0 is normal volume. Volume cannot be raised above 1.0.
function LoveSource:setVolume(volume)
end

---Sets the volume limits of the source. The limits have to be numbers from 0 to 1.
---@param min number @The minimum volume.
---@param max number @The maximum volume.
function LoveSource:setVolumeLimits(min, max)
end

---Stops a LoveSource.
function LoveSource:stop()
end

---Gets the currently playing position of the LoveSource.
---@param unit TimeUnit @The type of unit for the return value.
---@return number
function LoveSource:tell(unit)
end

-- endregion LoveSource
---The different distance models.
---
---Extended information can be found in the chapter "3.4. Attenuation By Distance" of the OpenAL 1.1 specification.
DistanceModel = {
    ---Sources do not get attenuated.
    ["none"] = 1,
    ---Inverse distance attenuation.
    ["inverse"] = 2,
    ---Inverse distance attenuation. Gain is clamped. In version 0.9.2 and older this is named '''inverse clamped'''.
    ["inverseclamped"] = 3,
    ---Linear attenuation.
    ["linear"] = 4,
    ---Linear attenuation. Gain is clamped. In version 0.9.2 and older this is named '''linear clamped'''.
    ["linearclamped"] = 5,
    ---Exponential attenuation.
    ["exponent"] = 6,
    ---Exponential attenuation. Gain is clamped. In version 0.9.2 and older this is named '''exponent clamped'''.
    ["exponentclamped"] = 7
}
---The different types of effects supported by love.audio.setEffect.
EffectType = {
    ---Plays multiple copies of the sound with slight pitch and time variation. Used to make sounds sound "fuller" or "thicker".
    ["chorus"] = 1,
    ---Decreases the dynamic range of the sound, making the loud and quiet parts closer in volume, producing a more uniform amplitude throughout time.
    ["compressor"] = 2,
    ---Alters the sound by amplifying it until it clips, shearing off parts of the signal, leading to a compressed and distorted sound.
    ["distortion"] = 3,
    ---Decaying feedback based effect, on the order of seconds. Also known as delay; causes the sound to repeat at regular intervals at a decreasing volume.
    ["echo"] = 4,
    ---Adjust the frequency components of the sound using a 4-band (low-shelf, two band-pass and a high-shelf) equalizer.
    ["equalizer"] = 5,
    ---Plays two copies of the sound; while varying the phase, or equivalently delaying one of them, by amounts on the order of milliseconds, resulting in phasing sounds.
    ["flanger"] = 6,
    ---Decaying feedback based effect, on the order of milliseconds. Used to simulate the reflection off of the surroundings.
    ["reverb"] = 7,
    ---An implementation of amplitude modulation; multiplies the source signal with a simple waveform, to produce either volume changes, or inharmonic overtones.
    ["ringmodulator"] = 8
}
---The different types of waveforms that can be used with the '''ringmodulator''' EffectType.
EffectWaveform = {
    ---A sawtooth wave, also known as a ramp wave. Named for its linear rise, and (near-)instantaneous fall along time.
    ["sawtooth"] = 1,
    ---A sine wave. Follows a trigonometric sine function.
    ["sine"] = 2,
    ---A square wave. Switches between high and low states (near-)instantaneously.
    ["square"] = 3,
    ---A triangle wave. Follows a linear rise and fall that repeats periodically.
    ["triangle"] = 4
}
---Types of filters for Sources.
FilterType = {
    ---Low-pass filter. High frequency sounds are attenuated.
    ["lowpass"] = 1,
    ---High-pass filter. Low frequency sounds are attenuated.
    ["highpass"] = 2,
    ---Band-pass filter. Both high and low frequency sounds are attenuated based on the given parameters.
    ["bandpass"] = 3
}
---Types of audio sources.
---
---A good rule of thumb is to use stream for music files and static for all short sound effects. Basically, you want to avoid loading large files into memory at once.
SourceType = {
    ---The whole audio is decoded.
    ["static"] = 1,
    ---The audio is decoded in chunks when needed.
    ["stream"] = 2,
    ---The audio must be manually queued by the user.
    ["queue"] = 3
}
---Units that represent time.
TimeUnit = {
    ---Regular seconds.
    ["seconds"] = 1,
    ---Audio samples.
    ["samples"] = 2
}
---Gets a list of the names of the currently enabled effects.
---@return table
function m.getActiveEffects()
end

---Gets the current number of simultaneously playing sources.
---@return number
function m.getActiveSourceCount()
end

---Returns the distance attenuation model.
---@return DistanceModel
function m.getDistanceModel()
end

---Gets the current global scale factor for velocity-based doppler effects.
---@return number
function m.getDopplerScale()
end

---Gets the settings associated with an effect.
---@param name string @The name of the effect.
---@return table
function m.getEffect(name)
end

---Gets the maximum number of active effects supported by the system.
---@return number
function m.getMaxSceneEffects()
end

---Gets the maximum number of active Effects in a single LoveSource object, that the system can support.
---@return number
function m.getMaxSourceEffects()
end

---Returns the orientation of the listener.
---@return number, number
function m.getOrientation()
end

---Returns the position of the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources.
---@return number, number, number
function m.getPosition()
end

---Gets a list of RecordingDevices on the system.
---
---The first device in the list is the user's default recording device. The list may be empty if there are no microphones connected to the system.
---
---Audio recording is currently not supported on iOS.
---@return table
function m.getRecordingDevices()
end

---Gets the current number of simultaneously playing sources.
---@return number
function m.getSourceCount()
end

---Returns the velocity of the listener.
---@return number, number, number
function m.getVelocity()
end

---Returns the master volume.
---@return number
function m.getVolume()
end

---Gets whether audio effects are supported in the system.
---@return boolean
function m.isEffectsSupported()
end

---Creates a new LoveSource usable for real-time generated sound playback with LoveSource:queue.
---@param samplerate number @Number of samples per second when playing.
---@param bitdepth number @Bits per sample (8 or 16).
---@param channels number @1 for mono or 2 for stereo.
---@param buffercount number @The number of buffers that can be queued up at any given time with LoveSource:queue. Cannot be greater than 64. A sensible default (~8) is chosen if no value is specified.
---@return LoveSource
function m.newQueueableSource(samplerate, bitdepth, channels, buffercount)
end

---Creates a new LoveSource from a filepath, LoveFile, LoveDecoder or LoveSoundData.
---
---Sources created from LoveSoundData are always static.
---@param filename string @The filepath to the audio file.
---@param type SourceType @Streaming or static source.
---@return LoveSource
---@overload fun(file:LoveFile, type:SourceType):LoveSource
---@overload fun(decoder:LoveDecoder, type:SourceType):LoveSource
---@overload fun(data:LoveFileData, type:SourceType):LoveSource
---@overload fun(data:LoveSoundData):LoveSource
function m.newSource(filename, type)
end

---Pauses specific or all currently played Sources.
---@return table
---@overload fun(source:LoveSource, ...:LoveSource):void
---@overload fun(sources:table):void
function m.pause()
end

---Plays the specified LoveSource.
---@param source LoveSource @The LoveSource to play.
---@overload fun(sources:table):void
---@overload fun(source1:LoveSource, source2:LoveSource, ...:LoveSource):void
function m.play(source)
end

---Sets the distance attenuation model.
---@param model DistanceModel @The new distance model.
function m.setDistanceModel(model)
end

---Sets a global scale factor for velocity-based doppler effects. The default scale value is 1.
---@param scale number @The new doppler scale factor. The scale must be greater than 0.
function m.setDopplerScale(scale)
end

---Defines an effect that can be applied to a LoveSource.
---
---Not all system supports audio effects. Use love.audio.isEffectsSupported to check.
---@param name string @The name of the effect.
---@param settings table @The settings to use for this effect, with the following fields:
---@return boolean
---@overload fun(name:string, enabled:boolean):boolean
function m.setEffect(name, settings)
end

---Sets whether the system should mix the audio with the system's audio.
---@param mix boolean @True to enable mixing, false to disable it.
---@return boolean
function m.setMixWithSystem(mix)
end

---Sets the orientation of the listener.
---@param fx, fy, fz number @Forward vector of the listener orientation.
---@param ux, uy, uz number @Up vector of the listener orientation.
function m.setOrientation(fx, fy, fz, ux, uy, uz)
end

---Sets the position of the listener, which determines how sounds play.
---@param x number @The x position of the listener.
---@param y number @The y position of the listener.
---@param z number @The z position of the listener.
function m.setPosition(x, y, z)
end

---Sets the velocity of the listener.
---@param x number @The X velocity of the listener.
---@param y number @The Y velocity of the listener.
---@param z number @The Z velocity of the listener.
function m.setVelocity(x, y, z)
end

---Sets the master volume.
---@param volume number @1.0 is max and 0.0 is off.
function m.setVolume(volume)
end

---Stops currently played sources.
---@overload fun(source:LoveSource):void
---@overload fun(source1:LoveSource, source2:LoveSource, ...:LoveSource):void
---@overload fun(sources:table):void
function m.stop()
end

return m

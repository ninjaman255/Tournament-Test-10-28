-- file name: event_emitter_api.lua
-- Easy-to-use EventEmitter API wrapper

local EventEmitter = {}

function EventEmitter.create()
    return Net.EventEmitter.new()
end

-- Helper function to create an event emitter with common setup
function EventEmitter.createWithHandlers(handlers)
    local emitter = Net.EventEmitter.new()
    
    if handlers then
        for event_name, handler in pairs(handlers) do
            if type(handler) == "function" then
                emitter:on(event_name, handler)
            end
        end
    end
    
    return emitter
end

-- Create a managed event emitter that automatically cleans up
function EventEmitter.managed()
    local emitter = Net.EventEmitter.new()
    
    return {
        emitter = emitter,
        
        on = function(self, event, callback)
            self.emitter:on(event, callback)
            return self
        end,
        
        once = function(self, event, callback)
            self.emitter:once(event, callback)
            return self
        end,
        
        emit = function(self, event, ...)
            self.emitter:emit(event, ...)
            return self
        end,

        on_any = function(self, event, ...)
            self.emitter:emit(event, ...)
            return self
        end,

        on_any_once = function(self, event, ...)
            self.emitter:on_any_once(event, ...)
            return self
        end,
        
        remove = function(self, event, callback)
            if callback then
                self.emitter:remove_listener(event, callback)
            else
                self.emitter:remove_on_any_listener()
            end
            return self
        end,
        
        destroy = function(self)
            self.emitter:destroy()
            return self
        end
    }
end

return EventEmitter
-- main.lua - API main file
local EventEmitterAPI = require("scripts/async-and-emitters/event_emitter_api")
local PromiseAPI = require("scripts/async-and-emitters/promise_api")
local AsyncUtils = require("scripts/async-and-emitters/async_utils")

-- Create the main API table
local API = {
    EventEmitter = EventEmitterAPI,
    Promise = PromiseAPI,
    Async = AsyncUtils
}

-- Add direct convenience methods
API.createEmitter = EventEmitterAPI.create
API.createManagedEmitter = EventEmitterAPI.managed
API.async = PromiseAPI.async
API.await = PromiseAPI.await
API.delay = PromiseAPI.delay
API.all = PromiseAPI.all
API.parallel = AsyncUtils.parallel
API.serial = AsyncUtils.serial

-- Example usage functions
function API.examples()
    return {
        -- Example 1: Simple event emitter
        eventExample = function()
            local emitter = API.createEmitter()
            emitter:on("test", function(data) print("Received:", data) end)
            emitter:emit("test", "Hello World!")
            return emitter
        end,
        
        -- Example 2: Async function with delay
        asyncExample = API.async(function()
            print("Starting async operation...")
            API.await(API.delay(1))
            print("Async operation completed!")
            return "Success"
        end),
        
        -- Example 3: Parallel operations
        parallelExample = function()
            return API.parallel(
                function() return API.delay(1).and_then(function() return "Task 1" end) end,
                function() return API.delay(2).and_then(function() return "Task 2" end) end,
                function() return API.delay(0.5).and_then(function() return "Task 3" end) end
            )
        end,
        
        -- Example 4: Promise chain
        chainExample = function()
            return API.Promise.chain(5,
                function(x) return x * 2 end,
                function(x) return x + 10 end,
                function(x) return x / 2 end
            )
        end
    }
end

-- Test the API (optional)
function API.test()
    print("Testing API components...")
    
    -- Test EventEmitter
    local emitter = API.createEmitter()
    emitter:on("api_test", function(msg) 
        print("✓ EventEmitter test passed:", msg) 
    end)
    emitter:emit("api_test", "Hello from API!")
    
    -- Test Promise
    API.Promise.resolve("API Promise test").and_then(function(msg)
        print("✓ Promise test passed:", msg)
    end)
    
    -- Test Async
    API.async(function()
        API.await(API.delay(0.1))
        print("✓ Async/await test passed")
    end)()
    
    print("API tests completed!")
end

return API

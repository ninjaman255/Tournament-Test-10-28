-- file name: async_utils.lua
-- Additional async utility functions

local AsyncUtils = {}

-- Run multiple async operations in parallel and wait for all
function AsyncUtils.parallel(...)
    local operations = {...}
    local promises = {}
    
    for i, operation in ipairs(operations) do
        if type(operation) == "function" then
            promises[i] = operation()
        else
            promises[i] = operation
        end
    end
    
    return Async.await_all(promises)
end

-- Run async operations sequentially
function AsyncUtils.serial(...)
    local operations = {...}
    
    return Promise.async(function()
        local results = {}
        for i, operation in ipairs(operations) do
            if type(operation) == "function" then
                results[i] = Async.await(operation())
            else
                results[i] = Async.await(operation)
            end
        end
        return results
    end)()
end

-- Debounce function calls
function AsyncUtils.debounce(fn, delay)
    local timeout
    return function(...)
        local args = {...}
        if timeout then
            timeout = nil
        end
        
        return Async.create_promise(function(resolve)
            timeout = Async.sleep(delay).and_then(function()
                resolve(fn(table.unpack(args)))
            end)
        end)
    end
end

-- Throttle function calls
function AsyncUtils.throttle(fn, delay)
    local lastCall = 0
    return function(...)
        local args = {...}
        local now = os.time()
        
        if now - lastCall >= delay then
            lastCall = now
            return fn(table.unpack(args))
        else
            return Async.create_promise(function(resolve)
                Async.sleep(delay - (now - lastCall)).and_then(function()
                    lastCall = os.time()
                    resolve(fn(table.unpack(args)))
                end)
            end)
        end
    end
end

-- Poll until a condition is met
function AsyncUtils.poll(condition, interval, timeout)
    local startTime = os.time()
    interval = interval or 1
    timeout = timeout or 30
    
    return Promise.async(function()
        while true do
            local result = Async.await(condition())
            if result then
                return result
            end
            
            if os.time() - startTime > timeout then
                error("Polling timeout after " .. timeout .. " seconds")
            end
            
            Async.await(Async.sleep(interval))
        end
    end)()
end

return AsyncUtils
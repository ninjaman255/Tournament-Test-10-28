-- file name: promise_api.lua
-- Easy-to-use Promise/Async API wrapper

local Promise = {}

-- Async wrapper functions
function Promise.async(fn)
    return function(...)
        local args = {...}
        local co = coroutine.create(function() 
            return fn(table.unpack(args))
        end)
        return Async.promisify(co)
    end
end

function Promise.await(value)
    return Async.await(value)
end

-- Create a resolved promise
function Promise.resolve(value)
    return Async.create_promise(function(resolve)
        resolve(value)
    end)
end

-- Create a promise that resolves after a delay
function Promise.delay(seconds)
    return Async.sleep(seconds)
end

-- Wait for all promises to complete
function Promise.all(promises)
    return Async.await_all(promises)
end

-- Chain multiple async operations
function Promise.chain(initialValue, ...)
    local operations = {...}
    local current = Promise.resolve(initialValue)
    
    for _, operation in ipairs(operations) do
        current = current.and_then(operation)
    end
    
    return current
end

-- Retry an async operation with exponential backoff
function Promise.retry(operation, maxRetries, initialDelay)
    local retries = 0
    local delay = initialDelay or 1
    
    local function attempt()
        return operation().and_then(
            function(value)
                return value
            end,
            function(error)
                retries = retries + 1
                if retries >= maxRetries then
                    error("Failed after " .. maxRetries .. " retries: " .. tostring(error))
                end
                
                print("Retry " .. retries .. " after " .. delay .. " seconds")
                return Promise.delay(delay).and_then(function()
                    delay = delay * 2
                    return attempt()
                end)
            end
        )
    end
    
    return attempt()
end

-- Timeout wrapper for promises
function Promise.timeout(promise, timeoutSeconds, timeoutMessage)
    local timeoutPromise = Async.sleep(timeoutSeconds).and_then(function()
        error(timeoutMessage or "Operation timed out")
    end)
    
    return Promise.all({promise, timeoutPromise}).and_then(function(results)
        return results[1]
    end)
end

-- Utility function to convert callback-based APIs to promise-based
function Promise.promisify(fn)
    return function(...)
        local args = {...}
        return Async.create_promise(function(resolve, reject)
            table.insert(args, function(success, result)
                if success then
                    resolve(result)
                else
                    reject(result)
                end
            end)
            fn(table.unpack(args))
        end)
    end
end

return Promise
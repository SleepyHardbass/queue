local AND = (bit or require("bit")).band

return(function(module)
    local mt = {__index = module}
    module.new = function(self)
        return setmetatable({
            head = 0, tail = 0, mask = 7, -- (2^N - 1)
            stack = {[0] = 0,0,0,0,0,0,0,0}, -- Circular buffer
        }, mt)
    end
    return module
end)({
    count = function(self) --|length
        return AND(self.tail - self.head, self.mask)
    end,
    empty = function(self) --|isEmpty
        return self.head == self.tail
    end,
    full = function(self) --|isFull
        return AND(self.tail + 1, self.mask) == self.head
    end,
    push = function(self, value) --|put|write|enqueue
        if self:full() then
            -- extend --
            local offset = self.mask + 1
            for i = 0, self.tail - 1 do
                self.stack[i + offset] = self.stack[i]
            end
            self.tail = self.mask + self.head
            self.mask = self.mask + self.mask + 1
        end
        self.stack[self.tail] = value
        self.tail = AND(self.tail + 1, self.mask)
        return self
    end,
    pull = function(self) --|get|read|dequeue
        if self:empty() then return nil end
        local value = self.stack[self.head]
        self.head = AND(self.head + 1, self.mask)
        return value
    end,
    peek = function(self) -- output the first item
        if self:empty() then return nil end
        return self.stack[self.head]
    end,
    -- output item if that index exists
    ipeek = function(self, index)
        if index < 0 or index > self:count() then return nil end
        return self.stack[AND(index + self.head, self.mask)]
    end,
    -- queue:foreach(print) | queue:foreach(save) | ect..
    foreach = function(self, callback)
        local stack = self.stack
        for i = 0, self:count() - 1 do
            callback(i, stack[AND(i + self.head, self.mask)])
        end
        return self
    end,
    __iterator = function(self, index, value)
        index = index + 1
        if index >= self:count() then return nil end
        return index, self.stack[AND(index + self.head, self.mask)]
    end,
    -- for i, v in queue:ipairs() do ... end
    ipairs = function(self)
        return self.__iterator, self, -1
    end,
    -- for v in queue:poll() do ... end
    poll = function(self)
        return self.pull, self
    end,
    pump = function(self, queue)
        for v in queue:poll() do self:push(v) end
        return self
    end,
    clear = function(self)
        self.head, self.tail = 0, 0
        return self
    end,
    free = function(self)
        for i = self.mask + 1, 8, -1 do
            self.stack[i] = nil
        end
        self.mask = 7
        self.stack[0], self.stack[1] = 0, 0
        self.stack[2], self.stack[3] = 0, 0
        self.stack[4], self.stack[5] = 0, 0
        self.stack[6], self.stack[7] = 0, 0
        return self:clear()
    end,
    -- queue:totable(mytable) --> table.concat(mytable, ", ") --> sting
    totable = function(self, output)
        output = output or {}
        local length = #output
        local stack = self.stack
        for i = 0, self:count() - 1 do
            output[length + i + 1] = stack[AND(i + self.head, self.mask)]
        end
        return output
    end,
    CG = function(self) -- alignment/trim/collectgarbage
        local template = {}
        local count = self:count()
        for i = 0, count - 1 do
            template[i] = self.stack[AND(i + self.head, self.mask)]
        end
        for i = count - 1, 0, -1 do
            self.stack[i] = template[i]
            template[i] = nil
        end
        for i = self.mask + 1, count, -1 do
            self.stack[i] = nil
        end
        template = nil
        self.head = 0
        self.tail = count
        -- pow(2, ceil( log2(count + 1) )) - 1
        self.mask = 2^math.ceil(math.log(count + 1)/math.log(2)) - 1
        return self, collectgarbage(), collectgarbage()
    end
})

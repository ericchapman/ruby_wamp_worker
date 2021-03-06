require 'thread'

class RedisStub
  attr_reader :data, :semaphore

  def initialize
    @data = {}
    @semaphore = Mutex.new
  end

  def lpush(key, data)
    self.semaphore.synchronize {
      list = self.data[key] || []
      list.unshift data
      self.data[key] = list
    }
  end

  def exists(key)
    self.semaphore.synchronize {
      self.data[key] != nil
    }
  end

  def get(key)
    self.semaphore.synchronize {
      self.data[key]
    }
  end

  def set(key, value, options={})
    self.semaphore.synchronize {
      self.data[key] = value
    }
  end

  def del(key)
    self.semaphore.synchronize {
      self.data.delete(key)
      1
    }
  end

  def rpop(key)
    self.semaphore.synchronize {
      (self.data[key] || []).pop
    }
  end

  def brpop(key, **args)
    value = nil
    timeout = false
    start_time = Time.new.to_i

    # BRPOP also supports an array of keys
    keys = key.is_a?(Array) ? key : [key]
    matched_key = nil

    while value == nil and not timeout
      self.semaphore.synchronize {
        keys.each do |temp_key|
          value = (self.data[temp_key] || []).pop
          if value != nil
            matched_key = temp_key
            break
          end
        end
      }

      if args[:timeout] != nil
        current_time = Time.new.to_i
        if current_time > args[:timeout]+start_time
          timeout = true
        end
      end
    end

    value != nil ? [matched_key, value] : nil
  end

  def incr(key)
    self.semaphore.synchronize {
      value = self.data[key] || 0
      value += 1
      self.data[key] = value
    }
  end

end
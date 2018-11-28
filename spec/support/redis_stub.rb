class RedisStub
  attr_reader :data

  def initialize
    @data = {}
  end

  def lpush(key, data)
    list = self.data[key] || []
    list.unshift data
    self.data[key] = list
  end

  def exists(key)
    self.data[key] != nil
  end

  def get(key)
    self.data[key]
  end

  def set(key, value, options={})
    self.data[key] = value
  end

  def delete(key)
    self.data.delete(key)
    1
  end

  def rpop(key)
    (self.data[key] || []).pop
  end

  def brpop(key, **args)
    (self.data[key] || []).pop
  end

  def incr(key)
    value = self.data[key] || 0
    value += 1
    self.data[key] = value
  end

end
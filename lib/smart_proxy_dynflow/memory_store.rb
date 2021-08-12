require 'singleton'

module Proxy::Dynflow
  class MemoryStore
    include Singleton

    def initialize
      @store = Proxy::MemoryStore.new
    end

    def add(task_id, step_id, name, content)
      @store[task_id, step_id, name] = content
    end

    def get(task_id, step_id, name)
      @store[task_id, step_id, name]
    end

    def drop(task_id)
      @store.delete(task_id)
    end
  end
end

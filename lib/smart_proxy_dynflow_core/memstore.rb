require 'singleton'

module SmartProxyDynflowCore
  class Memstore
    include Singleton

    def initialize
      @data = {}
    end

    def add(task_id, step_id, name, content)
      @data[task_id] ||= {}
      @data[task_id][step_id] ||= {}
      @data[task_id][step_id][name] = content
    end

    def get(task_id, step_id, name)
      @data.fetch(task_id, {}).fetch(step_id.to_i, {})[name]
    end

    def drop(task_id)
      @data.delete(task_id)
    end
  end
end

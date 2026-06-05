# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  class TaskLauncherRegistry
    # @rbs self.@registry: Hash[String, Class]

    #: (String, Class) -> void
    def self.register(name, launcher)
      registry[name] = launcher
    end

    #: (String, ?Class?) -> Class
    def self.fetch(name, default = nil)
      if default.nil?
        registry.fetch(name)
      else
        registry.fetch(name, default)
      end
    end

    #: (String) -> bool
    def self.key?(name)
      registry.key?(name)
    end

    #: () -> Array[String]
    def self.operations
      registry.keys
    end

    #: () -> Hash[String, Class]
    private_class_method def self.registry
      @registry ||= {}
    end
  end
end

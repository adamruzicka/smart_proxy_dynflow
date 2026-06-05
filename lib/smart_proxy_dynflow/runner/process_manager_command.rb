# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/process_manager'

module Proxy::Dynflow
  module Runner
    module ProcessManagerCommand
      # @rbs *command: String
      #: (*String) -> void
      def initialize_command(*command)
        @process_manager = ProcessManager.new(command) #: ProcessManager
        set_process_manager_callbacks(@process_manager)
        @process_manager.start!
        if @process_manager.done? && @process_manager.status == 255
          exception = RuntimeError.new(@process_manager.stderr.to_s)
          exception.set_backtrace Thread.current.backtrace
          publish_exception("Error running command '#{command.join(' ')}'", exception)
        end
      end

      #: (ProcessManager) -> void
      def set_process_manager_callbacks(pm) # rubocop:disable Naming/MethodParameterName
        pm.on_stdout do |data|
          publish_data(data, 'stdout')
          ''
        end
        pm.on_stderr do |data|
          publish_data(data, 'stderr')
          ''
        end
      end

      #: () -> void
      def refresh
        @process_manager.process(timeout: 0.1) unless @process_manager.done?
        publish_exit_status(@process_manager.status) if @process_manager.done?
      end

      #: () -> void
      def close
        @process_manager&.close
      end
    end
  end
end

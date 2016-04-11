module SmartProxyDynflowCore
  class Core

    attr_accessor :world

    def initialize
      @world = create_world
    end

    def create_world(&block)
      config = default_world_config(&block)
      ::Dynflow::World.new(config)
    end

    def persistence_conn_string
      return ENV['DYNFLOW_DB_CONN_STRING'] if ENV.key? 'DYNFLOW_DB_CONN_STRING'
      db_conn_string = 'sqlite:/'

      db_file = SETTINGS['smart_proxy_dynflow_core']['database']
      if db_file.nil? || db_file.empty?
        # TODO: Use some kind of logger
        STDERR.puts "Could not open DB for dynflow at '#{db_file}', will keep data in memory. Restart will drop all dynflow data."
      else
        db_conn_string += "/#{db_file}"
      end

      db_conn_string
    end

    def persistence_adapter
      ::Dynflow::PersistenceAdapters::Sequel.new persistence_conn_string
    end

    def default_world_config
      ::Dynflow::Config.new.tap do |config|
        config.auto_rescue = true
        config.logger_adapter = logger_adapter
        config.persistence_adapter = persistence_adapter
        yield config if block_given?
      end
    end

    def logger_adapter
      ::Dynflow::LoggerAdapters::Simple.new $stderr, 0
    end

    class << self
      attr_reader :instance

      def ensure_initialized
        return @instance if @instance
        @instance = SmartProxyDynflowCore::Core.new
        after_initialize_blocks.each(&:call)
        @instance
      end

      def web_console
        require 'dynflow/web'
        dynflow_console = ::Dynflow::Web.setup do
          # we can't use the proxy's after_actionvation hook, as
          # it happens before the Daemon forks the process (including
          # closing opened file descriptors)
          # TODO: extend smart proxy to enable hooks that happen after
          # the forking

          SmartProxyDynflowCore::Core.ensure_initialized
          set :world, SmartProxyDynflowCore::Core.world
        end
        dynflow_console
      end

      def world
        instance.world
      end

      def after_initialize(&block)
        after_initialize_blocks << block
      end

      private

      def after_initialize_blocks
        @after_initialize_blocks ||= []
      end
    end
  end
end

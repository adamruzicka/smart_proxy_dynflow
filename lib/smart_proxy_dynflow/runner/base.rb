# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  module Runner
    class Base
      attr_reader :id #: String
      attr_writer :logger #: Logger

      # @rbs *_args: untyped
      # @rbs suspended_action: untyped
      # @rbs id: String?
      #: (*untyped, ?suspended_action: untyped, ?id: String?) -> void
      def initialize(*_args, suspended_action: nil, id: nil)
        @suspended_action = suspended_action #: untyped
        @id = id || SecureRandom.uuid
        @exit_status = nil #: String?
        @exit_status_timestamp = nil #: Time?
        initialize_continuous_outputs
      end

      #: () -> Logger
      def logger
        @logger ||= Logger.new($stderr)
      end

      #: () -> Hash[untyped, Update]
      def run_refresh
        logger.debug('refreshing runner')
        refresh
        generate_updates
      end

      #: (untyped) -> Hash[untyped, Update]
      def external_event(_event)
        run_refresh
      end

      #: () -> void
      def start
        raise NotImplementedError
      end

      #: () -> void
      def refresh
        raise NotImplementedError
      end

      #: () -> void
      def kill
      end

      #: () -> void
      def close
      end

      #: () -> void
      def timeout
        publish_data('Timeout for execution passed, trying to stop the job', 'debug')
        kill
      end

      #: () -> Numeric?
      def timeout_interval
      end

      def publish_data(...)
        @continuous_output.add_output(...)
      end

      #: (String, Exception, ?bool) -> void
      def publish_exception(context, exception, fatal = true)
        logger.error("#{context} - #{exception.class} #{exception.message}:\n" + \
                     exception.backtrace.join("\n"))
        dispatch_exception context, exception
        publish_exit_status('EXCEPTION') if fatal
      end

      #: (String) -> void
      def publish_exit_status(status)
        @exit_status = status
        @exit_status_timestamp = Time.now.utc
      end

      #: (String, Exception) -> void
      def dispatch_exception(context, exception)
        @continuous_output.add_exception(context, exception)
      end

      #: () -> Hash[untyped, Update]
      def generate_updates
        return no_update if @continuous_output.empty? && @exit_status.nil?

        new_data = @continuous_output
        @continuous_output = Proxy::Dynflow::ContinuousOutput.new
        new_update(new_data, @exit_status)
      end

      #: () -> Hash[untyped, Update]
      def no_update
        {}
      end

      #: (ContinuousOutput, String?) -> Hash[untyped, Update]
      def new_update(data, exit_status)
        { @suspended_action => Runner::Update.new(data, exit_status, exit_status_timestamp: @exit_status_timestamp) }
      end

      #: () -> void
      def initialize_continuous_outputs
        @continuous_output = ::Proxy::Dynflow::ContinuousOutput.new
      end

      #: () -> Hash[untyped, Update]
      def run_refresh_output
        logger.debug('refreshing runner on demand')
        refresh
        generate_updates
      end
    end
  end
end

# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/action/shareable'
require 'smart_proxy_dynflow/action/external_polling'
require 'smart_proxy_dynflow/action/middleware/assemble_results'

module Proxy::Dynflow
  module Action
    class Runner < Shareable
      include ::Dynflow::Action::Cancellable
      include ::Proxy::Dynflow::Action::WithExternalPolling

      middleware.use ::Proxy::Dynflow::Action::Middleware::AssembleResults

      #: (untyped?) -> void
      def run(event = nil)
        case event
        when nil
          init_run
        when Proxy::Dynflow::Runner::Update
          process_update(event)
        when Proxy::Dynflow::Runner::ExternalEvent
          process_external_event(event)
        when ::Dynflow::Action::Cancellable::Cancel
          kill_run
        when ::Proxy::Dynflow::Action::WithExternalPolling::Poll
          poll
          suspend
        else
          raise "Unexpected event #{event.inspect}"
        end
      rescue => e
        action_logger.error(e)
        process_update(Proxy::Dynflow::Runner::Update.encode_exception('Proxy error', e))
      end

      #: () -> void
      def finalize
        # To mark the task as a whole as failed
        error! 'Script execution failed' if on_proxy? && failed_run?
      end

      #: () -> untyped
      def rescue_strategy_for_self
        ::Dynflow::Action::Rescue::Fail
      end

      #: () -> Proxy::Dynflow::Runner::Base
      def initiate_runner
        raise NotImplementedError
      end

      #: () -> void
      def init_run
        output[:result] = []
        output[:runner_id] = runner_dispatcher.start(suspended_action, initiate_runner)
        suspend
      end

      #: () -> Proxy::Dynflow::Runner::Dispatcher?
      def runner_dispatcher
        Proxy::Dynflow::Runner::Dispatcher.instance
      end

      #: () -> void
      def kill_run
        runner_dispatcher.kill(output[:runner_id])
        suspend
      end

      #: (Proxy::Dynflow::Runner::Update) -> void
      def finish_run(update)
        output[:exit_status] = update.exit_status
        output[:exit_status_timestamp] = update.exit_status_timestamp.to_f
        output[:result] = output_result
        drop_output_chunks!
      end

      #: (Proxy::Dynflow::Runner::ExternalEvent) -> void
      def process_external_event(event)
        runner_dispatcher.external_event(output[:runner_id], event)
        suspend
      end

      #: (Proxy::Dynflow::Runner::Update) -> void
      def process_update(update)
        output_chunk(update.continuous_output.raw_outputs) unless update.continuous_output.raw_outputs.empty?
        if update.exit_status
          finish_run(update)
        else
          suspend
        end
      end

      #: () -> void
      def poll
        runner_dispatcher.refresh_output(output[:runner_id])
      end

      #: () -> bool
      def failed_run?
        output[:exit_status] != 0
      end

      #: () -> Array[Hash[String, untyped]]
      def output_result
        (stored_output_chunks + (@pending_output_chunks || [])).map { |c| c[:chunk] }.reduce([], &:concat)
      end
    end
  end
end

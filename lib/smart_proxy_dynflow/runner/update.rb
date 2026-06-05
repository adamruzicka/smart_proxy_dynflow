# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/continuous_output'

module Proxy::Dynflow
  module Runner
    class Update
      attr_reader :continuous_output #: ContinuousOutput
      attr_reader :exit_status #: String?
      attr_reader :exit_status_timestamp #: Time?

      #: (ContinuousOutput, String?, ?exit_status_timestamp: Time?) -> void
      def initialize(continuous_output, exit_status, exit_status_timestamp: nil)
        @continuous_output = continuous_output
        @exit_status = exit_status
        @exit_status_timestamp = exit_status_timestamp || Time.now.utc if @exit_status
      end

      #: (String, Exception, ?bool) -> Update
      def self.encode_exception(context, exception, fatal = true)
        continuous_output = ::Proxy::Dynflow::ContinuousOutput.new
        continuous_output.add_exception(context, exception)
        new(continuous_output, fatal ? 'EXCEPTION' : nil)
      end
    end

    class ExternalEvent
      attr_reader :data #: Hash[untyped, untyped]

      #: (?Hash[untyped, untyped]) -> void
      def initialize(data = {})
        @data = data
      end
    end
  end
end

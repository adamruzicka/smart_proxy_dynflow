# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  class ContinuousOutput
    attr_accessor :raw_outputs #: Array[Hash[String, untyped]]

    # @rbs raw_outputs: Array[Hash[String, untyped]]
    #: (Array[Hash[String, untyped]]) -> void
    def initialize(raw_outputs = [])
      @raw_outputs = [] #: Array[Hash[String, untyped]]
      raw_outputs.each { |raw_output| add_raw_output(raw_output) }
    end

    #: (Hash[String, untyped]) -> void
    def add_raw_output(raw_output)
      missing_args = %w[output_type output timestamp] - raw_output.keys
      unless missing_args.empty?
        raise ArgumentError, "Missing args for raw output: #{missing_args.inspect}"
      end

      @raw_outputs << raw_output
    end

    #: () -> bool
    def empty?
      @raw_outputs.empty?
    end

    #: () -> Float?
    def last_timestamp
      return if @raw_outputs.empty?

      @raw_outputs.last.fetch('timestamp')
    end

    #: () -> void
    def sort!
      @raw_outputs.sort_by! { |record| record['timestamp'].to_f }
    end

    #: () -> String
    def humanize
      sort!
      raw_outputs.map { |output| output['output'] }.join("\n")
    end

    # @rbs context: String
    # @rbs exception: Exception
    # @rbs timestamp: Time
    # @rbs id: String?
    #: (String, Exception, ?timestamp: Time, ?id: String?) -> void
    def add_exception(context, exception, timestamp: Time.now.getlocal, id: nil)
      add_output(context + ": #{exception.class} - #{exception.message}", 'debug', timestamp: timestamp, id: id)
    end

    def add_output(...)
      add_raw_output(self.class.format_output(...))
    end

    # @rbs message: String
    # @rbs type: String
    # @rbs timestamp: Time
    # @rbs id: String?
    #: (String, ?String, ?timestamp: Time, ?id: String?) -> Hash[String, untyped]
    def self.format_output(message, type = 'debug', timestamp: Time.now.getlocal, id: nil)
      base = { 'output_type' => type,
               'output' => message,
               'timestamp' => timestamp.to_f }
      base['id'] = id if id
      base
    end
  end
end

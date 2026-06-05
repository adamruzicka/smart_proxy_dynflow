# rbs_inline: enabled
# frozen_string_literal: true

module Proxy
  module Dynflow
    class IOBuffer
      attr_accessor :io #: IO?
      attr_reader :buffer #: String

      #: (IO?) -> void
      def initialize(io)
        @buffer = '' #: String
        @io = io
        @callback = nil #: (^(String) -> String)?
      end

      # @rbs &block: ^(String) -> String
      #: () { (String) -> String } -> void
      def on_data(&block)
        @callback = block
      end

      #: () -> IO?
      def to_io
        @io
      end

      #: () -> String
      def to_s
        @buffer
      end

      #: () -> bool
      def empty?
        @buffer.empty?
      end

      #: () -> bool
      def closed?
        @io.closed?
      end

      #: () -> void
      def close
        @io.close unless @io.closed?
      end

      #: () -> void
      def read_available!
        data = ''
        loop { data += @io.read_nonblock(4096) }
      rescue IO::WaitReadable # rubocop:disable Lint/SuppressedException
      rescue EOFError
        close
      ensure
        @buffer += with_callback(data) unless data.empty?
      end

      #: () -> void
      def write_available!
        until @buffer.empty?
          n = @io.write_nonblock(@buffer)
          @buffer = @buffer.bytes.drop(n).pack('c*')
        end
      rescue IO::WaitWritable # rubocop:disable Lint/SuppressedException
      rescue EOFError
        close
      end

      #: (String) -> void
      def add_data(data)
        @buffer += data
      end

      private

      #: (String) -> String
      def with_callback(data)
        if @callback
          @callback.call(data)
        else
          data
        end
      end
    end
  end
end

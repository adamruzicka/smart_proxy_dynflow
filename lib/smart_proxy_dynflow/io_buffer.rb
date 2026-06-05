# rbs_inline: enabled
# frozen_string_literal: true

module Proxy
  module Dynflow
    # A buffer around an IO object providing buffering and convenience methods
    # for non-blocking reads and writes.
    #
    # @note Using a single IOBuffer with a single IO for both reads and writes might not be a good idea. If you need to use a single IO for both reads and writes, wrap it in two separate IOBuffers.
    #
    # @attr_accessor [IO] io The IO which the buffer wraps
    # @attr_reader [String] buffer The buffer where the data read from the underlying IO is buffered
    class IOBuffer
      attr_accessor :io #: IO?
      attr_reader :buffer #: String

      # @param [IO] io The IO object to be buffered
      #: (IO?) -> void
      def initialize(io)
        @buffer = '' #: String
        @io = io
        @callback = nil #: (^(String) -> String)?
      end

      # Sets a callback to be executed each time data is read from the
      # underlying IO.
      #
      # @note Note that if the callback is provided, the buffer will store the return value of the callback instead of the raw data.
      #
      # @yieldparam [String] data read from the underlying IO
      # @yieldreturn [String] data to be buffered
      # @return [void]
      # @rbs &block: ^(String) -> String
      #: () { (String) -> String } -> void
      def on_data(&block)
        @callback = block
      end

      # Exposes the underlying IO so that the buffer itself can be used in IO.select calls.
      #
      # @return [IO] the underlying IO
      #: () -> IO?
      def to_io
        @io
      end

      # Exposes the contents of the buffer as a String
      #
      # @return [String] the buffered data
      #: () -> String
      def to_s
        @buffer
      end

      # Checks whether the buffer is empty
      #
      # @return [true, false] whether the buffer is empty
      #: () -> bool
      def empty?
        @buffer.empty?
      end

      # Checks whether the underlying IO is closed
      #
      # @return [true, false] whether the underlying IO is closed
      #: () -> bool
      def closed?
        @io.closed?
      end

      # Closes the underlying IO. Does nothing if the IO is already closed.
      #
      # @return [void]
      #: () -> void
      def close
        @io.close unless @io.closed?
      end

      # Reads all the data that is currently waiting in the IO and stores it. If
      # EOFError is encountered during the read, the underlying IO is closed.
      #
      # @return [void]
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

      # Writes all the data into the IO that can be written without blocking. It
      # is a no-op if there are no data to be written. If an EOFError is
      # encountered during the write, the underlying IO is closed.
      #
      # @return [void]
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

      # Adds data to the buffer. If the buffer is used for writing, then this
      # should be the preferred method of queueing the data to be written.
      #
      # @return [void]
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

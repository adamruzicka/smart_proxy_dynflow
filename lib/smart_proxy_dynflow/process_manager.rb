# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/io_buffer'

module Proxy
  module Dynflow
    class ProcessManager
      attr_reader :stdin #: IOBuffer
      attr_reader :stdout #: IOBuffer
      attr_reader :stderr #: IOBuffer
      attr_reader :pid #: Integer?
      attr_reader :status #: Integer?

      #: (String | Array[String]) -> void
      def initialize(command)
        @command = command #: String | Array[String]
        @stdin  = IOBuffer.new(nil)
        @stdout = IOBuffer.new(nil)
        @stderr = IOBuffer.new(nil)
        @pid = nil #: Integer?
        @status = nil #: Integer?
      end

      #: () -> ProcessManager
      def run!
        start! unless started?
        process until done?
        self
      end

      #: () -> void
      def start!
        in_read,  in_write  = IO.pipe
        out_read, out_write = IO.pipe
        err_read, err_write = IO.pipe

        @stdin.io  = in_write
        @stdout.io = out_read
        @stderr.io = err_read

        @pid = spawn(*@command, :in => in_read, :out => out_write, :err => err_write)
        [in_read, out_write, err_write].each(&:close)
      rescue Errno::ENOENT => e
        [in_read, in_write, out_read, out_write, err_read, err_write].each(&:close)
        @pid = -1
        @status = 255
        @stderr.add_data(e.message)
      end

      #: () -> bool
      def started?
        !pid.nil?
      end

      #: () -> bool
      def done?
        started? && !status.nil?
      end

      #: (?timeout: Numeric?) -> void
      def process(timeout: nil)
        raise 'Cannot process until the manager is started' unless started?

        writers = [@stdin].reject { |buf| buf.empty? || buf.closed? }
        readers = [@stdout, @stderr].reject(&:closed?)

        if readers.empty? && writers.empty?
          finish
          return
        end

        pid, status = Process.waitpid2(@pid, Process::WNOHANG)
        timeout = 1 if pid

        ready_readers, ready_writers = IO.select(readers, writers, nil, timeout)
        (ready_readers || []).each(&:read_available!)
        (ready_writers || []).each(&:write_available!)

        finish(status) if pid
      end

      # @rbs &block: ^(String) -> String
      #: () { (String) -> String } -> void
      def on_stdout(&block)
        @stdout.on_data(&block)
      end

      # @rbs &block: ^(String) -> String
      #: () { (String) -> String } -> void
      def on_stderr(&block)
        @stderr.on_data(&block)
      end

      #: () -> void
      def close
        [@stdin, @stdout, @stderr].each(&:close)
      end

      private

      #: (?Process::Status?) -> void
      def finish(status = nil)
        close
        if status.nil? && @pid != -1 && !done?
          _pid, status = Process.wait2(@pid)
          @status = status.exitstatus
        elsif status
          @status = status.exitstatus
        end
      end
    end
  end
end

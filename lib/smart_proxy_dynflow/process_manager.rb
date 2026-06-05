# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/io_buffer'

module Proxy
  module Dynflow
    # An abstraction for managing local processes.
    #
    # It can be used to:
    # - spawn a local process
    # - track its lifecycle
    # - communicate with it through its standard input, output and error
    # - step through the execution one event at a time or start the child process and wait until it finishes
    #
    # @example Run date command and collect its output
    #   pm = ProcessManager.new('date')
    #   pm.run!
    #   pm.status #=> 0
    #   pm.stdout.to_s.chomp #=> "Thu Feb  3 04:27:42 PM CET 2022"
    #
    # @example Run a shell loop, outputting all the lines it generates
    #   pm = ProcessManager.new(['/bin/sh', '-c', 'for i in 1 2 3; do echo $i; sleep 1; done'])
    #   pm.on_stdout { |data| puts data; '' }
    #   pm.run!
    #   #=> 1
    #   #=> 2
    #   #=> 3
    #
    # @example Run bc (calculator) interactively and count down from 10 to 0
    #   pm = ProcessManager.new('bc')
    #   pm.on_stdout do |data|
    #     if data.match?(/^\d+/)
    #       n = data.to_i
    #       if n.zero?
    #         pm.stdin.to_io.close
    #       else
    #         pm.stdin.add_data("#{n} - 1\n")
    #       end
    #     end
    #     data
    #   end
    #   pm.stdin.add_data("10\n")
    #   pm.run!
    #   pm.stdout.to_s.lines #=. ["10\n", "9\n", "8\n", "7\n", "6\n", "5\n", "4\n", "3\n", "2\n", "1\n", "0\n"]
    #
    # @attr_reader [Proxy::Dynflow::IOBuffer] stdin IOBuffer buffering writes to child process' standard input
    # @attr_reader [Proxy::Dynflow::IOBuffer] stdout IOBuffer buffering reads from child process' standard output
    # @attr_reader [Proxy::Dynflow::IOBuffer] stderr IOBuffer buffering reads from child process' standard error
    # @attr_reader [nil, Integer] pid Process id of the child process, nil if the process was not started yet, -1 if the process could not be started
    # @attr_reader [nil, Integer] status Exit status of the child process. nil if the child process has not finished yet, 255 if the process could not be started
    class ProcessManager
      attr_reader :stdin #: IOBuffer
      attr_reader :stdout #: IOBuffer
      attr_reader :stderr #: IOBuffer
      attr_reader :pid #: Integer?
      attr_reader :status #: Integer?

      # @param [String, [String], [Hash, String]] command A command to run in one of the forms accepted by Kernel.spawn
      #: (String | Array[String]) -> void
      def initialize(command)
        @command = command #: String | Array[String]
        @stdin  = IOBuffer.new(nil)
        @stdout = IOBuffer.new(nil)
        @stderr = IOBuffer.new(nil)
        @pid = nil #: Integer?
        @status = nil #: Integer?
      end

      # Starts the process manager and runs it until it finishes
      #
      # @return [ProcessManager] the process manager itself to allow method chaining
      #: () -> ProcessManager
      def run!
        start! unless started?
        process until done?
        self
      end

      # Starts the child process. It creates 3 pipes for communicating with the
      # child process and the forks it. The process manager is considered done
      # if the child process cannot be started.
      #
      # @return [void]
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

      # Determines whether the process manager already forked off its child process
      #
      # @return [true, false] whether the process manager already forked off its child process
      #: () -> bool
      def started?
        !pid.nil?
      end

      # Determines whether the child process of the process manager already finished
      #
      # @return [true, false] whether the child process of the process manager already finished
      #: () -> bool
      def done?
        started? && !status.nil?
      end

      # If all the pipes connected to the child process are closed, it marks the
      # execution as complete and performs cleanup.
      #
      # @param timeout [nil, Numeric] controls how long this call should wait for data to become available. Waits indefinitely if nil.
      # @return [void]
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

      # Sets block to be executed each time data is read from child process' standard output
      #
      # @return [void]
      # @rbs &block: ^(String) -> String
      #: () { (String) -> String } -> void
      def on_stdout(&block)
        @stdout.on_data(&block)
      end

      # Sets block to be executed each time data is read from child process' standard error
      #
      # @return [void]
      # @rbs &block: ^(String) -> String
      #: () { (String) -> String } -> void
      def on_stderr(&block)
        @stderr.on_data(&block)
      end

      # Makes the process manager close all the pipes it may have opened to communicate with the child process
      #
      # @return [void]
      #: () -> void
      def close
        [@stdin, @stdout, @stderr].each(&:close)
      end

      private

      # Makes the process manager finish its run, closing opened FDs and reaping the child process
      #
      # @return [void]
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

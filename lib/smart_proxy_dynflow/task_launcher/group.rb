# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/runner'

module Proxy::Dynflow
  module TaskLauncher
    class AbstractGroup < Batch
      #: (*untyped) -> void
      def initialize(*args)
        super
        @runner_id = SecureRandom.uuid #: String
      end

      #: () -> Class
      def self.runner_class
        raise NotImplementedError
      end

      #: () -> Class
      def action_class
        Action::SingleRunnerBatch
      end

      #: (untyped, Hash[String, untyped]) -> untyped
      def launch_children(parent, input_hash)
        super(parent, input_hash)
        trigger(parent, Action::BatchRunner, self, input_hash, @runner_id)
      end

      #: () -> String
      def operation
        raise NotImplementedError
      end

      #: (Hash[String, untyped]) -> Hash[String, Hash[Symbol, untyped]]
      def runner_input(input)
        input.reduce({}) do |acc, (id, input)|
          input = { :execution_plan_id => results[id][:task_id],
                    :run_step_id => 2,
                    :input => input }
          acc.merge(id => input)
        end
      end

      private

      #: (untyped) -> Single
      def child_launcher(parent)
        Single.new(world, callback, :parent => parent, :action_class_override => Action::OutputCollector)
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def transform_input(input)
        tmp = wipe_callback(input)
        input.merge('action_input' => tmp['action_input'].merge(:runner_id => @runner_id))
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def wipe_callback(input)
        callback = input['action_input']['callback']
        input.merge('action_input' => input['action_input'].merge('callback' => nil, :task_id => callback['task_id']))
      end
    end
  end
end

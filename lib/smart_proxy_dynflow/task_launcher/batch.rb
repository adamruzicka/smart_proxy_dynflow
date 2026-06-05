# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  module TaskLauncher
    class Batch < Abstract
      #: (untyped) -> void
      def launch!(input)
        plan = trigger(nil, action_class, self, input)
        results[:parent] = format_result(plan)
      end

      #: (untyped, Hash[String, untyped]) -> Array[untyped]
      def launch_children(parent, input_hash)
        input_hash.map do |task_id, input|
          launcher = child_launcher(parent)
          triggered = launcher.launch!(transform_input(input), id: task_id)
          results[task_id] = launcher.results
          triggered
        end
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def prepare_batch(input_hash)
        input_hash
      end

      #: (untyped) -> Single
      def child_launcher(parent)
        Single.new(world, callback, :parent => parent)
      end

      private

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def transform_input(input)
        input
      end

      #: () -> Class
      def action_class
        Proxy::Dynflow::Action::Batch
      end
    end
  end
end

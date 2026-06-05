# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow::Action
  class Batch < ::Dynflow::Action
    include Dynflow::Action::WithSubPlans

    # { execution_plan_uuid => { :action_class => Klass, :input => input } }
    #: (Proxy::Dynflow::TaskLauncher::Abstract, Hash[String, untyped]) -> untyped
    def plan(launcher, input_hash)
      plan_self :input_hash => input_hash,
                :launcher => launcher.to_hash
    end

    #: () -> untyped
    def create_sub_plans
      Proxy::Dynflow::TaskLauncher::Abstract
        .new_from_hash(world, input[:launcher])
        .launch_children(self, input[:input_hash])
    end

    #: () -> untyped
    def rescue_strategy
      Dynflow::Action::Rescue::Fail
    end

    #: (untyped) -> void
    def notify_on_finish(_plans)
      # Do nothing
    end
  end
end

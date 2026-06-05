# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow::Action
  class SingleRunnerBatch < Batch
    include Dynflow::Action::WithPollingSubPlans

    #: (Proxy::Dynflow::TaskLauncher::AbstractGroup, Hash[String, untyped]) -> untyped
    def plan(launcher, input_hash)
      results = super
      plan_action BatchCallback, input_hash, results.output[:results]
    end

    #: (?bool) -> untyped
    def check_for_errors!(optional = true)
      super unless optional
    end

    #: () -> void
    def on_finish
      output[:results] = sub_plans.map(&:entry_action).reduce({}) do |acc, cur|
        acc.merge(cur.execution_plan_id => cur.output)
      end
    end

    #: () -> void
    def finalize
      output.delete(:results)
      check_for_errors!
    end

    #: () -> untyped
    def rescue_strategy_for_self
      Dynflow::Action::Rescue::Skip
    end
  end
end

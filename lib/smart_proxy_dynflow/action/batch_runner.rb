# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/action/runner'

module Proxy::Dynflow::Action
  class BatchRunner < ::Proxy::Dynflow::Action::Runner
    #: (Proxy::Dynflow::TaskLauncher::AbstractGroup, Hash[String, untyped], String) -> untyped
    def plan(launcher, input, runner_id)
      plan_self :targets => launcher.runner_input(input), :operation => launcher.operation, :runner_id => runner_id
    end

    #: () -> Proxy::Dynflow::Runner::Base
    def initiate_runner
      launcher = Proxy::Dynflow::TaskLauncherRegistry.fetch(input[:operation])
      launcher.runner_class.new(input[:targets], suspended_action: suspended_action, id: input[:runner_id])
    end
  end
end

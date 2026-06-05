# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow::Action
  class Shareable < ::Dynflow::Action
    #: (Hash[String | Symbol, untyped]) -> untyped
    def plan(input)
      input = input.dup
      callback = input.delete('callback')
      if callback
        input[:task_id] = callback['task_id']
      else
        input[:task_id] ||= SecureRandom.uuid
      end

      planned_action = plan_self(input)
      # code only applicable, when run with SmartProxyDynflowCore in place
      if on_proxy? && callback
        plan_action(Proxy::Dynflow::Callback::Action, callback, planned_action.output)
      end
    end

    private

    #: () -> bool
    def on_proxy?
      true
    end
  end
end

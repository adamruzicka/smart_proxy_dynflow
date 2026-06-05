# rbs_inline: enabled
# frozen_string_literal: true

require 'smart_proxy_dynflow/action/external_polling'
require 'smart_proxy_dynflow/action/runner'

module Proxy
  module Dynflow
    module Helpers
      #: () -> untyped
      def world
        Proxy::Dynflow::Core.world
      end

      #: (task_id: String, ?clear: bool) -> bool
      def authorize_with_token(task_id:, clear: true)
        if request.env.key? 'HTTP_AUTHORIZATION'
          if defined?(::Proxy::Dynflow)
            auth = request.env['HTTP_AUTHORIZATION']
            basic_prefix = /\ABasic /
            if !auth.to_s.empty? && auth =~ basic_prefix &&
               Proxy::Dynflow::OtpManager.authenticate(auth.gsub(basic_prefix, ''),
                                                       expected_user: task_id, clear: clear)
              Log.instance.debug('authorized with token')
              return true
            end
          end
          halt 403, MultiJson.dump(:error => 'Invalid username or password supplied')
        end
        false
      end

      #: (*untyped) -> Hash[Symbol, untyped]
      def trigger_task(*args)
        triggered = world.trigger(*args)
        { :task_id => triggered.id }
      end

      #: (String) -> Hash[Symbol, untyped]
      def cancel_task(task_id)
        execution_plan = world.persistence.load_execution_plan(task_id)
        cancel_events = execution_plan.cancel
        { :task_id => task_id, :canceled_steps_count => cancel_events.size }
      end

      #: (String) -> Hash[Symbol, untyped]
      def task_status(task_id)
        ep = world.persistence.load_execution_plan(task_id)
        execution_plan_status(ep)
      rescue KeyError => _e
        status 404
        {}
      end

      #: (Array[String]) -> Hash[String, Hash[Symbol, untyped]]
      def tasks_statuses(task_ids)
        eps = world.persistence.find_execution_plans(filters: { uuid: task_ids })
        eps.reduce({}) do |acc, ep|
          acc.update(ep.id => execution_plan_status(ep))
        end
      end

      #: (String?) -> Hash[Symbol, untyped]
      def tasks_count(state)
        state ||= 'all'
        filter = state != 'all' ? { :filters => { :state => [state] } } : {}
        count = world.persistence.find_execution_plan_counts(filter)
        { :count => count, :state => state }
      end

      #: (String, Hash[String, untyped]) -> untyped
      def dispatch_external_event(task_id, params)
        world.event(task_id,
                    params['step_id'].to_i,
                    ::Proxy::Dynflow::Runner::ExternalEvent.new(params))
      end

      #: (untyped, untyped) -> void
      def refresh_output(execution_plan, action)
        if action.is_a?(Proxy::Dynflow::Action::WithExternalPolling) && %i[running suspended].include?(action.run_step&.state)
          world.event(execution_plan.id, action.run_step_id, Proxy::Dynflow::Action::WithExternalPolling::Poll)
        end
      end

      #: (untyped) -> Hash[Symbol, untyped]
      def execution_plan_status(plan)
        actions = plan.actions.map do |action|
          refresh_output(plan, action)
          action.to_hash
        end
        plan.to_hash.merge(:actions => actions)
      end
    end
  end
end

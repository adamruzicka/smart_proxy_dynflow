require 'rest-client'

module SmartProxyDynflowCore
  module Callback
    class Request
      def callback(callback, data)
        payload = { :callback => callback, :data => data }.to_json
        response = RestClient.post callback_uri, payload
        if response.code != "200"
          raise "Failed performing callback to smart proxy: #{response.code} #{response.body}"
        end
        response
      end

      def self.callback(callback, data)
        self.new.callback(callback, data)
      end

      private

      def callback_uri
        SETTINGS['smart_proxy_dynflow_core'].fetch(:callback_url) +
          '/dynflow/tasks/callback'
      end
    end

    class Action < ::Dynflow::Action
      def plan(callback, data)
        plan_self(:callback => callback, :data => data)
      end

      def run
        Callback::Request.callback(input[:callback], input[:data])
      end
    end

    module PlanHelper
      def plan_with_callback(input)
        input = input.dup
        callback = input.delete('callback')

        planned_action = plan_self(input)
        plan_action(::SmartProxyDynflowCore::Callback::Action, callback, planned_action.output) if callback
      end
    end
  end
end

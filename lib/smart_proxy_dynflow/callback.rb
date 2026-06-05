# rbs_inline: enabled
# frozen_string_literal: true

require 'rest-client'

module Proxy::Dynflow
  module Callback
    class Request < ::Proxy::HttpRequest::ForemanRequest
      #: (untyped, untyped) -> untyped
      def self.send_to_foreman_tasks(callback_info, data)
        self.new.callback({ :callback => callback_info, :data => data }.to_json)
      end

      #: (String) -> untyped
      def callback(payload)
        request = request_factory.create_post '/foreman_tasks/api/tasks/callback',
                                              payload
        response = send_request(request)

        if response.code.to_s != "200"
          raise "Failed performing callback to Foreman server: #{response.code} #{response.body}"
        end

        response
      end
    end

    class Action < ::Dynflow::Action
      #: (Hash[String, untyped], untyped) -> untyped
      def plan(callback, data)
        plan_self(:callback => callback, :data => data)
      end

      #: () -> untyped
      def run
        Callback::Request.send_to_foreman_tasks(input[:callback], input[:data])
      ensure
        input.delete(:data)
      end
    end

    module PlanHelper
      #: (Hash[String, untyped]) -> void
      def plan_with_callback(input)
        input = input.dup
        callback = input.delete('callback')

        planned_action = plan_self(input)
        plan_action(Callback::Action, callback, planned_action.output) if callback
      end
    end
  end
end

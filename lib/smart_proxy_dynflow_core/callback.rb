require 'rest-client'

module SmartProxyDynflowCore
  module Callback
    class Request
      def callback(callback, data)
        payload = { :callback => callback, :data => data }.to_json
        response = callback_resource.post payload
        if response.code != 200
          raise "Failed performing callback to smart proxy: #{response.code} #{response.body}"
        end
        response
      end

      def self.callback(callback, data)
        self.new.callback(callback, data)
      end

      private

      def callback_resource
        @resource ||= RestClient::Resource.new(
          SETTINGS['smart_proxy_dynflow_core'].fetch(:callback_url) +
            '/dynflow/tasks/callback',
          ssl_options
        )
      end

      def ssl_options
        if SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'].fetch(:use_https, false)
          client_key = File.read SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'].fetch(:ssl_private_key)
          client_cert = File.read SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'].fetch(:ssl_certificate)
          {
            :ssl_client_cert => OpenSSL::X509::Certificate.new(client_cert),
            :ssl_client_key  => OpenSSL::PKey::RSA.new(client_key),
            :ssl_ca_file     => SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'].fetch(:ssl_ca_file),
            :verify_ssl      => OpenSSL::SSL::VERIFY_PEER
          }
        else
          {}
        end
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

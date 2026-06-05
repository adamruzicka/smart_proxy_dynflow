# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow::Action
  class BatchCallback < ::Dynflow::Action
    #: (Hash[String, Hash[String, untyped]], Hash[String, untyped]) -> untyped
    def plan(input_hash, results)
      # In input_hash there are complete inputs for all the actions for which this is reporting.
      # Trim it down to only the bare minimum we actually need.
      callbacks = input_hash.reduce({}) do |acc, (key, value)|
        acc.merge(key => value['action_input']['callback'])
      end
      plan_self :targets => callbacks, :results => results
    end

    #: () -> untyped
    def run
      payload = format_payload(input['targets'], input['results'])
      Proxy::Dynflow::Callback::Request.new.callback({ :callbacks => payload }.to_json)
    ensure
      input.delete(:results)
    end

    private

    #: (Hash[String, untyped], Hash[String, untyped]) -> Array[Hash[Symbol, untyped]]
    def format_payload(input_hash, results)
      input_hash.map do |task_id, callback|
        { :callback => callback, :data => results[task_id] }
      end
    end
  end
end

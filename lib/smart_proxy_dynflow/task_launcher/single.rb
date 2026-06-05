# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  module TaskLauncher
    class Single < Abstract
      #: () -> Hash[Symbol, untyped]
      def self.input_format
        { :action_class => "MyActionClass", :action_input => {} }
      end

      #: (Hash[String, untyped], ?id: String?) -> untyped
      def launch!(input, id: nil)
        triggered = trigger(options[:parent],
                            action_class(input),
                            with_callback(input.fetch('action_input', {})),
                            id: id)
        @results = format_result(triggered)
        triggered
      end
    end
  end
end

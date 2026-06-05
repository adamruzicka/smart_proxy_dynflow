# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  module TaskLauncher
    class Abstract
      attr_reader :callback #: untyped
      attr_reader :options #: Hash[Symbol, untyped]
      attr_reader :results #: Hash[untyped, untyped]
      attr_reader :world #: untyped

      #: (untyped, untyped, ?Hash[Symbol, untyped]) -> void
      def initialize(world, callback, options = {})
        @world = world
        @callback = callback
        @options = options
        @results = {} #: Hash[untyped, untyped]
      end

      #: (untyped) -> void
      def launch!(_input)
        raise NotImplementedError
      end

      #: () -> untyped
      def self.input_format; end

      #: () -> Hash[Symbol, untyped]
      def to_hash
        { :class => self.class.to_s, :callback => callback, :options => options }
      end

      #: (untyped, Hash[Symbol, untyped]) -> Abstract
      def self.new_from_hash(world, hash)
        ::Dynflow::Utils.constantize(hash[:class]).new(world, hash[:callback], hash[:options])
      end

      private

      #: (untyped) -> Hash[Symbol, untyped]
      def format_result(result)
        if result.triggered?
          { :result => 'success', :task_id => result.execution_plan_id }
        else
          plan = world.persistence.load_execution_plan(result.id)
          { :result => 'error', :errors => plan.errors }
        end
      end

      #: (Hash[String, untyped]) -> Class
      def action_class(input)
        options[:action_class_override] || ::Dynflow::Utils.constantize(input['action_class'])
      end

      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]
      def with_callback(input)
        input.merge(:callback_host => callback)
      end

      # @rbs parent: untyped
      # @rbs klass: Class
      # @rbs *input: untyped
      # @rbs id: String?
      #: (untyped, Class, *untyped, ?id: String?) -> untyped
      def trigger(parent, klass, *input, id: nil)
        world.trigger do
          world.plan_with_options(caller_action: parent, action_class: klass, args: input, id: id)
        end
      end
    end
  end
end

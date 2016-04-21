require 'test_helper'

module SmartProxyDynflowCore
  class CallbackTest < MiniTest::Spec
    class DummyAction < ::Dynflow::Action
      include Callback::PlanHelper

      def plan
        plan_with_callback('callback' => { 'task_id' => '123', 'step_id' => 123 }, 'name' => 'World')
      end

      def run
        output[:result] = "Hello #{input[:name]}"
      end
    end

    describe Callback::Action do
      it 'sends the data to the Foreman using the callback API' do
        Callback::Request.expects(:callback).with({ 'task_id' => '123', 'step_id' => 123 },
                                                  { 'result' => 'Hello World' })
        triggered = WORLD.trigger(DummyAction)
        triggered.finished.wait
      end
    end
  end
end

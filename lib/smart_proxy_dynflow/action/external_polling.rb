# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow::Action
  module WithExternalPolling
    Poll = Algebrick.atom

    #: (untyped?) -> untyped
    def run(event = nil)
      if event.is_a?(Poll)
        poll
        suspend
      else
        super
      end
    end

    #: () -> void
    def poll; end
  end
end

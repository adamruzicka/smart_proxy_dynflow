# rbs_inline: enabled
# frozen_string_literal: true

module Proxy::Dynflow
  class Settings
    #: () -> untyped
    def self.instance
      Proxy::Dynflow::Plugin.settings
    end
  end
end

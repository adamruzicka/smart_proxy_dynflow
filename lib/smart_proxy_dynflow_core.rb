require 'dynflow'
require 'smart_proxy_dynflow_core/request_id_middleware'
require 'smart_proxy_dynflow_core/logger_middleware'
require 'smart_proxy_dynflow_core/middleware/keep_current_request_id'
require 'smart_proxy_dynflow_core/task_launcher_registry'
require 'foreman_tasks_core'
require 'smart_proxy_dynflow_core/log'
require 'smart_proxy_dynflow_core/settings'
require 'smart_proxy_dynflow_core/core'
require 'smart_proxy_dynflow_core/memstore'
require 'smart_proxy_dynflow_core/helpers'
require 'smart_proxy_dynflow_core/callback'
require 'smart_proxy_dynflow_core/api'

module SmartProxyDynflowCore
  SmartProxyDynflowCore::Memstore.instance # Force initialization
  Core.after_initialize do |dynflow_core|
    ForemanTasksCore.dynflow_setup(dynflow_core.world)
  end
  Core.register_silencer_matchers ForemanTasksCore.silent_dead_letter_matchers
end

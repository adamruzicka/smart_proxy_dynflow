require 'webrick/https'
require 'smart_proxy_dynflow_core/bundler_helper'
module SmartProxyDynflowCore
  class Launcher

    def self.launch!
      self.new.start
    end

    def start
      load_settings!
      SmartProxyDynflowCore::Core.ensure_initialized
      Rack::Server.new(rack_settings).start
    end

    def load_settings!
      config_dir = File.join(File.dirname(__FILE__), '..', '..', 'config')
      settings = YAML.load(File.read(File.join(config_dir, 'settings.yml.default')))
      settings.merge!(YAML.load(File.read(File.join(config_dir, 'settings.yml')))) if File.exists? File.join(config_dir, 'settings.yml')
      plugins = Dir[File.join(config_dir, 'settings.d', '*.yml')].reduce({}) do |acc, cur|
        acc.update(File.basename(cur).gsub(/\.yml$/, '') => YAML.load(File.read(cur)))
      end

      BundlerHelper.require_groups(:default)

      SmartProxyDynflowCore::SETTINGS.merge!(plugins.merge('smart_proxy_dynflow_core' => settings))
    end

    private

    def rack_settings
      settings = if https_enabled?
                   # TODO: Use a logger
                   puts "Using HTTPS"
                   https_app
                 else
                   # TODO: Use a logger
                   puts "Using HTTP"
                   {}
                 end
      settings.merge(base_settings)
    end

    def app
      Rack::Builder.new do
        map '/api' do
          run SmartProxyDynflowCore::Api
        end

        map '/' do
          run SmartProxyDynflowCore::Core.web_console
        end
      end
    end

    def base_settings
      {
        :app => app,
        :Host => SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'].fetch(:Host),
        :Port => SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'].fetch(:Port),
        :daemonize => false
      }
    end

    def https_app
      ssl_options  = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      ssl_options |= OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE if defined?(OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE)
      # This is required to disable SSLv3 on Ruby 1.8.7
      ssl_options |= OpenSSL::SSL::OP_NO_SSLv2 if defined?(OpenSSL::SSL::OP_NO_SSLv2)
      ssl_options |= OpenSSL::SSL::OP_NO_SSLv3 if defined?(OpenSSL::SSL::OP_NO_SSLv3)
      ssl_options |= OpenSSL::SSL::OP_NO_TLSv1 if defined?(OpenSSL::SSL::OP_NO_TLSv1)

      {
        :SSLEnable => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
        :SSLPrivateKey => ssl_private_key,
        :SSLCertificate => ssl_certificate,
        :SSLCACertificateFile => SETTINGS['smart_proxy_dynflow_core'].fetch(:ssl_ca_file),
        :SSLOptions => ssl_options
      }
    end

    def https_enabled?
      SmartProxyDynflowCore::SETTINGS['smart_proxy_dynflow_core'][:use_https]
    end

    def ssl_private_key
      OpenSSL::PKey::RSA.new(File.read(SETTINGS['smart_proxy_dynflow_core'].fetch(:ssl_private_key)))
    rescue Exception => e
      # TODO: Use a logger
      STDERR.puts "Unable to load private SSL key. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
      # logger.error "Unable to load private SSL key. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
      raise e
    end

    def ssl_certificate
      OpenSSL::X509::Certificate.new(File.read(SETTINGS['smart_proxy_dynflow_core'].fetch(:ssl_certificate)))
    rescue Exception => e
      # TODO: Use a logger
      STDERR.puts "Unable to load SSL certificate. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
      # logger.error "Unable to load SSL certificate. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
      raise e
    end
  end
end

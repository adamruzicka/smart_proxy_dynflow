# rbs_inline: enabled
# frozen_string_literal: true

require 'base64'
require 'securerandom'

module Proxy::Dynflow
  class OtpManager
    # @rbs self.@password: Hash[String, String]

    #: (String) -> String
    def self.generate_otp(username)
      otp = SecureRandom.hex
      passwords[username] = otp.to_s
    end

    #: (String, String) -> String?
    def self.drop_otp(username, password)
      passwords.delete(username) if passwords[username] == password
    end

    #: () -> Hash[String, String]
    def self.passwords
      @password ||= {}
    end

    # @rbs hash: String
    # @rbs expected_user: String?
    # @rbs clear: bool
    #: (String, ?expected_user: String?, ?clear: bool) -> bool
    def self.authenticate(hash, expected_user: nil, clear: true)
      plain = Base64.decode64(hash)
      username, otp = plain.split(':', 2)
      if expected_user && expected_user != username
        return false
      end

      password_matches = passwords[username] == otp
      passwords.delete(username) if clear && password_matches
      password_matches
    end

    #: (String, String) -> String
    def self.tokenize(username, password)
      Base64.strict_encode64("#{username}:#{password}")
    end
  end
end

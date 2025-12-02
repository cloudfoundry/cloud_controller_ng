# -*- encoding: utf-8 -*-

require 'time'
require 'cgi'
require 'base64'
require 'openssl'
require 'digest/md5'

module Aliyun
  module STS
    ##
    # Util functions to help generate formatted Date, signatures,
    # etc.
    #
    module Util

      class << self

        include Common::Logging

        # Calculate request signatures
        def get_signature(verb, params, key)
          logger.debug("Sign, verb: #{verb}, params: #{params}")

          cano_query = params.sort.map {
            |k, v| [CGI.escape(k), CGI.escape(v)].join('=') }.join('&')

          string_to_sign =
            verb + '&' + CGI.escape('/') + '&' + CGI.escape(cano_query)

          logger.debug("String to sign: #{string_to_sign}")

          Util.sign(key + '&', string_to_sign)
        end

        # Sign a string using HMAC and BASE64
        # @param [String] key the secret key
        # @param [String] string_to_sign the string to sign
        # @return [String] the signature
        def sign(key, string_to_sign)
          Base64.strict_encode64(
            OpenSSL::HMAC.digest('sha1', key, string_to_sign))
        end

      end # self
    end # Util
  end # STS
end # Aliyun

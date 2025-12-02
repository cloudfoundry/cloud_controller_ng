# -*- encoding: utf-8 -*-

require 'time'
require 'base64'
require 'openssl'
require 'digest/md5'

module Aliyun
  module OSS

    ##
    # Util functions to help generate formatted Date, signatures,
    # etc.
    #
    module Util

      # Prefix for OSS specific HTTP headers
      HEADER_PREFIX = "x-oss-"

      class << self

        include Common::Logging

        # Calculate request signatures
        def get_signature(key, verb, headers, resources)
          logger.debug("Sign, headers: #{headers}, resources: #{resources}")

          content_md5 = headers['content-md5'] || ""
          content_type = headers['content-type'] || ""
          date = headers['date']

          cano_headers = headers.select { |k, v| k.start_with?(HEADER_PREFIX) }
                         .map { |k, v| [k.downcase.strip, v.strip] }
                         .sort.map { |k, v| [k, v].join(":") + "\n" }.join

          cano_res = resources[:path] || "/"
          sub_res = (resources[:sub_res] || {})
                    .sort.map { |k, v| v ? [k, v].join("=") : k }.join("&")
          cano_res += "?#{sub_res}" unless sub_res.empty?

          string_to_sign =
            "#{verb}\n#{content_md5}\n#{content_type}\n#{date}\n" +
            "#{cano_headers}#{cano_res}"

          Util.sign(key, string_to_sign)
        end

        # Sign a string using HMAC and BASE64
        # @param [String] key the secret key
        # @param [String] string_to_sign the string to sign
        # @return [String] the signature
        def sign(key, string_to_sign)
          logger.debug("String to sign: #{string_to_sign}")

          Base64.strict_encode64(
            OpenSSL::HMAC.digest('sha1', key, string_to_sign))
        end

        # Calculate content md5
        def get_content_md5(content)
          Base64.strict_encode64(OpenSSL::Digest::MD5.digest(content))
        end

        # Symbolize keys in Hash, recursively
        def symbolize(v)
          if v.is_a?(Hash)
            result = {}
            v.each_key { |k| result[k.to_sym] = symbolize(v[k]) }
            result
          elsif v.is_a?(Array)
            result = []
            v.each { |x| result << symbolize(x) }
            result
          else
            v
          end
        end

        # Get a crc value of the data
        def crc(data, init_crc = 0)
          CrcX::crc64(init_crc, data, data.size)
        end

        # Calculate a value of the crc1 combine with crc2. 
        def crc_combine(crc1, crc2, len2)
          CrcX::crc64_combine(crc1, crc2, len2)
        end

        def crc_check(crc_a, crc_b, operation)
          if crc_a.nil? || crc_b.nil? || crc_a.to_i != crc_b.to_i
            logger.error("The crc of #{operation} between client and oss is not inconsistent. crc_a=#{crc_a} crc_b=#{crc_b}")
            fail CrcInconsistentError.new("The crc of #{operation} between client and oss is not inconsistent.")
          end
        end

        def ensure_bucket_name_valid(name)
          unless (name =~ %r|^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$|)
            fail ClientError, "The bucket name is invalid."
          end
        end  

      end # self
    end # Util
  end # OSS
end # Aliyun

# Monkey patch to support #to_bool
class String
  def to_bool
    return true if self =~ /^true$/i
    false
  end
end
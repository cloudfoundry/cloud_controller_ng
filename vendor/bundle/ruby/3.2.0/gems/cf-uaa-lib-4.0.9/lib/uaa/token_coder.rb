#--
# Cloud Foundry
# Copyright (c) [2009-2014] Pivotal Software, Inc. All Rights Reserved.
#
# This product is licensed to you under the Apache License, Version 2.0 (the "License").
# You may not use this product except in compliance with the License.
#
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the
# subcomponent's license, as noted in the LICENSE file.
#++

require "openssl"
require "uaa/util"

module CF::UAA

# this code does not support the given token signature algorithim
class SignatureNotSupported < DecodeError; end

# this instance policy does not accept the given token signature algorithim
class SignatureNotAccepted < DecodeError; end

class InvalidSignature < DecodeError; end
class InvalidTokenFormat < DecodeError; end
class TokenExpired < AuthError; end
class InvalidAudience < AuthError; end

# This class is for OAuth Resource Servers.
# Resource Servers get tokens and need to validate and decode them,
# but they do not obtain them from the Authorization Server. This
# class is for resource servers which accept bearer JWT tokens.
#
# For more on JWT, see the JSON Web Token RFC here:
# {http://tools.ietf.org/id/draft-ietf-oauth-json-web-token-05.html}
#
# An instance of this class can be used to decode and verify the contents
# of a bearer token. Methods of this class can validate token signatures
# with a secret or public key, and they can also enforce that the token
# is for a particular audience.
class TokenCoder

  def self.init_digest(algo) # @private
    OpenSSL::Digest.new(algo.sub('HS', 'sha').sub('RS', 'sha'))
  end

  def self.normalize_options(opts) # @private
    opts = opts.dup
    pk = opts[:pkey]
    opts[:pkey] = OpenSSL::PKey::RSA.new(pk) if pk && !pk.is_a?(OpenSSL::PKey::PKey)
    opts[:audience_ids] = Util.arglist(opts[:audience_ids])
    opts[:algorithm] = 'HS256' unless opts[:algorithm]
    opts[:verify] = true unless opts.key?(:verify)
    opts[:accept_algorithms] = Util.arglist(opts[:accept_algorithms],
        ["HS256", "HS384", "HS512", "RS256", "RS384", "RS512"])
    opts
  end

  # Constructs a signed JWT.
  # @param token_body Contents of the token in any object that can be converted to JSON.
  # @param options (see #initialize)
  # @return [String] a signed JWT token string in the form "xxxx.xxxxx.xxxx".
  def self.encode(token_body, options = {}, obsolete1 = nil, obsolete2 = nil)
    unless options.is_a?(Hash) && obsolete1.nil? && obsolete2.nil?
      # deprecated: def self.encode(token_body, skey, pkey = nil, algo = 'HS256')
      warn "WARNING: #{self.class}##{__method__} is deprecated with these parameters. Please use options hash."
      options = {skey: options}
      options[:pkey], options[:algorithm] = obsolete1, obsolete2
    end
    options = normalize_options(options)
    algo = options[:algorithm]
    segments = [Util.json_encode64("typ" => "JWT", "alg" => algo)]
    segments << Util.json_encode64(token_body)
    if ["HS256", "HS384", "HS512"].include?(algo)
      sig = OpenSSL::HMAC.digest(init_digest(algo), options[:skey], segments.join('.'))
    elsif ["RS256", "RS384", "RS512"].include?(algo)
      sig = options[:pkey].sign(init_digest(algo), segments.join('.'))
    elsif algo == "none"
      sig = ""
    else
      raise SignatureNotSupported, "unsupported signing method"
    end
    segments << Util.encode64(sig)
    segments.join('.')
  end

  # Decodes a JWT token and optionally verifies the signature. Both a
  # symmetrical key and a public key can be provided for signature verification.
  # The JWT header indicates what signature algorithm was used and the
  # corresponding key is used to verify the signature (if +verify+ is true).
  # @param [String] token A JWT token as returned by {TokenCoder.encode}
  # @param options (see #initialize)
  # @return [Hash] the token contents
  def self.decode(token, options = {}, obsolete1 = nil, obsolete2 = nil)
    unless options.is_a?(Hash) && obsolete1.nil? && obsolete2.nil?
      # deprecated: def self.decode(token, skey = nil, pkey = nil, verify = true)
      warn "WARNING: #{self.class}##{__method__} is deprecated with these parameters. Please use options hash."
      options = {skey: options}
      options[:pkey], options[:verify] = obsolete1, obsolete2
    end
    options = normalize_options(options)
    segments = token.split('.')
    raise InvalidTokenFormat, "Not enough or too many segments" unless [2,3].include? segments.length
    header_segment, payload_segment, crypto_segment = segments
    signing_input = [header_segment, payload_segment].join('.')
    header = Util.json_decode64(header_segment)
    payload = Util.json_decode64(payload_segment, (:sym if options[:symbolize_keys]))
    unless options[:verify]
      warn "WARNING: Decoding token without verifying it was signed by its authoring UAA"
      return payload
    end
    raise SignatureNotAccepted, "Signature algorithm not accepted" unless
        options[:accept_algorithms].include?(algo = header["alg"])
    if algo == 'none'
      warn "WARNING: Decoding token that explicitly states it has not been signed by an authoring UAA"
      return payload
    end
    signature = Util.decode64(crypto_segment)
    if ["HS256", "HS384", "HS512"].include?(algo)
      raise InvalidSignature, "Signature verification failed" unless
          options[:skey] && constant_time_compare(signature, OpenSSL::HMAC.digest(init_digest(algo), options[:skey], signing_input))
    elsif ["RS256", "RS384", "RS512"].include?(algo)
      raise InvalidSignature, "Signature verification failed" unless
          options[:pkey] && options[:pkey].verify(init_digest(algo), signature, signing_input)
    else
      raise SignatureNotSupported, "Algorithm not supported"
    end
    payload
  end

  # Decodes a JWT token to extract its expiry time
  # @param [String] token A JWT token as returned by {TokenCoder.encode}
  # @return [Integer] exp expiry timestamp
  def self.decode_token_expiry(token)
    segments = token.split('.')
    raise InvalidTokenFormat, "Not enough or too many segments" unless [2,3].include? segments.length
    header_segment, payload_segment, crypto_segment = segments
    payload = Util.json_decode64(payload_segment, :sym)
    payload[:exp]
  end

  # Takes constant time to compare 2 strings (HMAC digests in this case)
  # to avoid timing attacks while comparing the HMAC digests
  # @param [String] a: the first digest to compare
  # @param [String] b: the second digest to compare
  # @return [boolean] true if they are equal, false otherwise
  def self.constant_time_compare(a, b)
    if a.length != b.length
      return false
    end
  
    result = 0
    a.chars.zip(b.chars).each do |x, y|
      result |= x.ord ^ y.ord
    end
    
    result == 0
  end

  # Creates a new token en/decoder for a service that is associated with
  # the the audience_ids, the symmetrical token validation key, and the
  # public and/or private keys.
  # @param [Hash] options Supported options:
  #   * :audience_ids [Array<String>, String] -- An array or space separated
  #     string of values which indicate the token is intended for this service
  #     instance. It will be compared with tokens as they are decoded to ensure
  #     that the token was intended for this audience.
  #   * :skey [String] -- used to sign and validate tokens using symmetrical
  #     key algoruthms
  #   * :pkey [String, File, OpenSSL::PKey::PKey] -- may be a String or File in
  #     PEM or DER formats. May include public and/or private key data. The
  #     private key is used to sign tokens and the public key is used to
  #     validate tokens.
  #   * :algorithm [String] -- Sets default used for encoding. May be HS256,
  #     HS384, HS512, RS256, RS384, RS512, or none.
  #   * :verify [String] -- Verifies signatures when decoding tokens. Defaults
  #     to +true+.
  #   * :accept_algorithms [String, Array<String>] -- An Array or space separated
  #     string of values which list what algorthms are accepted for token
  #     signatures. Defaults to all possible values of :algorithm except 'none'.
  # @note the TokenCoder instance must be configured with the appropriate
  #   key material to support particular algorithm families and operations
  #   -- i.e. :pkey must include a private key in order to sign tokens with
  #   the RS algorithms.
  def initialize(options = {}, obsolete1 = nil, obsolete2 = nil)
    unless options.is_a?(Hash) && obsolete1.nil? && obsolete2.nil?
      # deprecated: def initialize(audience_ids, skey, pkey = nil)
      warn "#{self.class}##{__method__} is deprecated with these parameters. Please use options hash."
      options = {audience_ids: options }
      options[:skey], options[:pkey] = obsolete1, obsolete2
    end
    @options = self.class.normalize_options(options)
  end

  # Encode a JWT token. Takes a hash of values to use as the token body.
  # Returns a signed token in JWT format (header, body, signature).
  # @param token_body (see TokenCoder.encode)
  # @param [String] algorithm -- overrides default. See {#initialize} for possible values.
  # @return (see TokenCoder.encode)
  def encode(token_body = {}, algorithm = nil)
    token_body[:aud] = @options[:audience_ids] if @options[:audience_ids] && !token_body[:aud] && !token_body['aud']
    token_body[:exp] = Time.now.to_i + 7 * 24 * 60 * 60 unless token_body[:exp] || token_body['exp']
    self.class.encode(token_body, algorithm ? @options.merge(algorithm: algorithm) : @options)
  end

  # Returns hash of values decoded from the token contents. If the
  # audience_ids were specified in the options to this instance (see #initialize)
  # and the token does not contain one or more of those audience_ids, an
  # AuthError will be raised. AuthError is raised if the token has expired.
  # @param [String] auth_header (see Scim.initialize#auth_header)
  # @return (see TokenCoder.decode)
  def decode(auth_header)
    decode_at_reference_time(auth_header, Time.now.to_i)
  end

  # Returns hash of values decoded from the token contents,
  # taking reference_time as the comparison time for expiration. If the
  # audience_ids were specified in the options to this instance (see #initialize)
  # and the token does not contain one or more of those audience_ids, an
  # AuthError will be raised. AuthError is raised if the token has expired.
  # @param [String] auth_header (see Scim.initialize#auth_header)
  # @param [Integer] reference_time
  # @return (see TokenCoder.decode)
  def decode_at_reference_time(auth_header, reference_time)
    unless auth_header && (tkn = auth_header.split(' ')).length == 2 && tkn[0] =~ /^bearer$/i
      raise InvalidTokenFormat, "invalid authentication header: #{auth_header}"
    end
    reply = self.class.decode(tkn[1], @options)
    auds = Util.arglist(reply[:aud] || reply['aud'])
    if @options[:audience_ids] && (!auds || (auds & @options[:audience_ids]).empty?)
      raise InvalidAudience, "invalid audience: #{auds}"
    end
    exp = reply[:exp] || reply['exp']
    unless exp.is_a?(Integer) && exp > reference_time
      raise TokenExpired, "token expired"
    end
    reply
  end
end

end

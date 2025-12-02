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

require 'uaa/http'

module CF::UAA

# Provides interfaces to various UAA endpoints that are not in the context
# of an overall class of operations like SCIM resources or OAuth2 tokens.
class Info
  include Http

  attr_accessor :target
  attr_reader :key_style

  # @param [String] target The base URL of the server. For example the target could
  #   be {https://login.cloudfoundry.com}, {https://uaa.cloudfoundry.com}, or
  #   {http://localhost:8080/uaa}.
  # @param [Hash] options can be
  #   * +:symbolize_keys+, If set to true, response hashes will have symbols for their keys, otherwise
  #     string keys are returned.
  def initialize(target, options = {})
    self.target = target
    self.symbolize_keys = options[:symbolize_keys]
    initialize_http_options(options)
  end

  # sets whether the keys in returned hashes should be symbols.
  # @return [Boolean] the new state
  def symbolize_keys=(bool)
    @key_style = bool ? :sym : nil
  end

  # Gets information about the user authenticated by the token in the
  # +auth_header+. It GETs from the +target+'s +/userinfo+ endpoint and
  # returns user information as specified by OpenID Connect.
  # @see http://openid.net/connect/
  # @see http://openid.net/specs/openid-connect-standard-1_0.html#userinfo_ep
  # @see http://openid.net/specs/openid-connect-messages-1_0.html#anchor9
  # @param (see Misc.server)
  # @param [String] auth_header see {TokenInfo#auth_header}
  # @return [Hash]
  def whoami(auth_header)
    json_get(target, "/userinfo?schema=openid", key_style, "authorization" => auth_header)
  end

  # Gets basic information about the target server, including version number,
  # commit ID, and links to API endpoints.
  # @return [Hash]
  def server
    reply = json_get(target, '/login', key_style)
    return reply if reply && (reply[:prompts] || reply['prompts'])
    raise BadResponse, "Invalid response from target #{target}"
  end

  # Gets a base url for the associated UAA from the target server by inspecting the
  # links returned from its info endpoint.
  # @return [String] url of UAA (or the target itself if it didn't provide a response)
  def discover_uaa
    info = server
    links = info['links'] || info[:links]
    uaa = links && (links['uaa'] || links[:uaa])

    uaa || target
  end

  # Gets the key from the server that is used to validate token signatures. If
  # the server is configured to use a symetric key, the caller must authenticate
  # by providing a a +client_id+ and +client_secret+. If the server
  # is configured to sign with a private key, this call will retrieve the
  # public key and +client_id+ must be nil.
  # @param (see Misc.server)
  # @return [Hash]
  def validation_key(client_id = nil, client_secret = nil)
    hdrs = client_id && client_secret ?
        { "authorization" => Http.basic_auth(client_id, client_secret)} : {}
    json_get(target, "/token_key", key_style, hdrs)
  end

  # Gets all currently valid token verification keys. If the server has had
  # its signing key changed, then +/token_key+ will return a verification key
  # that does not match a JWT token issued before the change. To validate the
  # signature of these tokens, refer to the +kid+ header of the JWT token. The
  # +validation_keys_hash+ method returns a hash of all currently valid
  # verification keys, indexed by +kid+. To retrieve symmetric keys as part of
  # the result, client credentials are required.
  # @param (see Misc.server)
  # @return [Hash]
  def validation_keys_hash(client_id = nil, client_secret = nil)
    hdrs = client_id && client_secret ?
        { "authorization" => Http.basic_auth(client_id, client_secret)} : {}
    response = json_get(target, "/token_keys", key_style, hdrs)

    keys_map = {}

    response['keys'].each do |key|
      keys_map[key['kid']] = key
    end

    keys_map
  end

  # Sends +token+ to the server to validate and decode. Authenticates with
  # +client_id+ and +client_secret+. If +audience_ids+ are specified and the
  # token's "aud" attribute does not contain one or more of the audience_ids,
  # raises AuthError -- meaning the token is not for this audience.
  # @param (see Misc.server)
  # @param [String] token an access token as retrieved by {TokenIssuer}. See
  #   also {TokenInfo}.
  # @param [String] token_type as retrieved by {TokenIssuer}. See {TokenInfo}.
  # @return [Hash] contents of the token
  def decode_token(client_id, client_secret, token, token_type = "bearer", audience_ids = nil)
    reply = json_parse_reply(key_style, *request(target, :post, '/check_token',
                                                 Util.encode_form(token: token),
                                                 "authorization" => Http.basic_auth(client_id, client_secret),
                                                 "content-type" => Http::FORM_UTF8,"accept" => Http::JSON_UTF8))

    auds = Util.arglist(reply[:aud] || reply['aud'])
    if audience_ids && (!auds || (auds & audience_ids).empty?)
      raise AuthError, "invalid audience: #{auds.join(' ')}"
    end
    reply
  end

  # Gets information about the given password, including a strength score and
  # an indication of what strength is required.
  # @param (see Misc.server)
  # @return [Hash]
  def password_strength(password)
    json_parse_reply(key_style, *request(target, :post, '/password/score',
        Util.encode_form(password: password), "content-type" => Http::FORM_UTF8,
        "accept" => Http::JSON_UTF8))
  end

end

end

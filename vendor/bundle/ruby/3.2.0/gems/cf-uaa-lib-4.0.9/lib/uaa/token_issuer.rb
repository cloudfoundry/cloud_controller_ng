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

require 'securerandom'
require "digest"
require 'uaa/http'
require 'cgi'

module CF::UAA

# The TokenInfo class is returned by various TokenIssuer methods. It holds access
# and refresh tokens as well as token meta-data such as token type and
# expiration time. See {TokenInfo#info} for contents.
class TokenInfo

  # Information about the current token. The info hash MUST include
  # access_token, token_type and scope (if granted scope differs from requested
  # scope). It should include expires_in. It may include refresh_token, scope,
  # and other values from the auth server.
  # @return [Hash]
  attr_reader :info

  # Normally instantiated by {TokenIssuer}.
  def initialize(info) @info = info  end

  # Constructs a string for use in an authorization header from the contents of
  # the TokenInfo.
  # @return [String] Typically a string such as "bearer xxxx.xxxx.xxxx".
  def auth_header
    "#{@info[:token_type] || @info['token_type']} #{@info[:access_token] || @info['access_token']}"
  end

end

# Client Apps that want to get access to resource servers on behalf of their
# users need to get tokens via authcode and implicit flows,
# request scopes, etc., but they don't need to process tokens. This
# class is for these use cases.
#
# In general most of this class is an implementation of the client pieces of
# the OAuth2 protocol. See {http://tools.ietf.org/html/rfc6749}
class TokenIssuer

  include Http

  private
  @client_auth_method = 'client_secret_basic'

  def random_state; SecureRandom.hex end

  def parse_implicit_params(encoded_params, state)
    params = Util.decode_form(encoded_params)
    raise BadResponse, "mismatched state" unless state && params.delete('state') == state
    raise TargetError.new(params), "error response from #{@target}" if params['error']
    raise BadResponse, "no type and token" unless params['token_type'] && params['access_token']
    exp = params['expires_in'].to_i
    params['expires_in'] = exp if exp.to_s == params['expires_in']
    TokenInfo.new(Util.hash_keys!(params, @key_style))
  rescue URI::InvalidURIError, ArgumentError
    raise BadResponse, "received invalid response from target #{@target}"
  end

  # returns a CF::UAA::TokenInfo object which includes the access token and metadata.
  def request_token(params)
    if scope = Util.arglist(params.delete(:scope))
      params[:scope] = Util.strlist(scope)
    end
    headers = {'content-type' => FORM_UTF8, 'accept' => JSON_UTF8}
    if @client_auth_method == 'client_secret_basic' && @client_secret && @client_id
      if @basic_auth
        headers['authorization'] = Http.basic_auth(@client_id, @client_secret)
      else
        headers['X-CF-ENCODED-CREDENTIALS'] = 'true'
        headers['authorization'] = Http.basic_auth(CGI.escape(@client_id), CGI.escape(@client_secret))
      end
    elsif @client_auth_method == 'client_secret_post' && @client_secret && @client_id
      params[:client_id] = @client_id
      params[:client_secret] = @client_secret
    elsif @client_id && params[:code_verifier]
      params[:client_id] = @client_id
    else
      headers['X-CF-ENCODED-CREDENTIALS'] = 'true'
      headers['authorization'] = Http.basic_auth(CGI.escape(@client_id || ''), CGI.escape(@client_secret || ''))
    end
    reply = json_parse_reply(@key_style, *request(@token_target, :post,
        '/oauth/token', Util.encode_form(params), headers))
    raise BadResponse unless reply[jkey :token_type] && reply[jkey :access_token]
    TokenInfo.new(reply)
  end

  def authorize_path_args(response_type, redirect_uri, scope, state = random_state, args = {})
    params = args.merge(client_id: @client_id, response_type: response_type,
        redirect_uri: redirect_uri, state: state)
    params[:scope] = scope = Util.strlist(scope) if scope = Util.arglist(scope)
    params[:nonce] = state
    if not @code_verifier.nil?
      params[:code_challenge] = get_challenge
      params[:code_challenge_method] = 'S256'
    end
    "/oauth/authorize?#{Util.encode_form(params)}"
  end

  def jkey(k) @key_style ? k : k.to_s end

  public

  # @param [String] target The base URL of a UAA's oauth authorize endpoint.
  #   For example the target would be {https://login.cloudfoundry.com} if the
  #   endpoint is {https://login.cloudfoundry.com/oauth/authorize}.
  #   The target would be {http://localhost:8080/uaa} if the endpoint
  #   is {http://localhost:8080/uaa/oauth/authorize}.
  # @param [String] client_id The oauth2 client id, see
  #   {http://tools.ietf.org/html/rfc6749#section-2.2}
  # @param [String] client_secret Needed to authenticate the client for all
  #   grant types except implicit.
  # @param [Hash] options can be
  #   * +:token_target+, the base URL of the oauth token endpoint -- if
  #     not specified, +target+ is used.
  #   * +:symbolize_keys+, if true, returned hash keys are symbols.
  def initialize(target, client_id, client_secret = nil, options = {})
    @target, @client_id, @client_secret = target, client_id, client_secret
    @token_target = options[:token_target] || target
    @key_style = options[:symbolize_keys] ? :sym : nil
    @basic_auth = options[:basic_auth] == true ? true : false
    @client_auth_method = options[:client_auth_method] || 'client_secret_basic'
    @code_verifier = options[:code_verifier] || nil
    if @code_verifier.nil? && options[:use_pkce] && options[:use_pkce] == true
      @code_verifier = get_verifier
    end
    initialize_http_options(options)
  end

  # Allows an app to discover what credentials are required for
  # {#implicit_grant_with_creds}.
  # @return [Hash] of credential names with type and suggested prompt value,
  #   e.g. !{"username":["text","Email"],"password":["password","Password"]}
  def prompts
    reply = json_get(@target, '/login')
    return reply[jkey :prompts] if reply && reply[jkey :prompts]
    raise BadResponse, "No prompts in response from target #{@target}"
  end

  # Gets an access token in a single call to the UAA with the user
  # credentials used for authentication.
  # @param credentials should be an object such as a hash that can be converted
  #   to a json representation of the credential name/value pairs corresponding to
  #   the keys retrieved by {#prompts}.
  # @return [TokenInfo]
  def implicit_grant_with_creds(credentials, scope = nil)
    # this manufactured redirect_uri is a convention here, not part of OAuth2
    redir_uri = "https://uaa.cloudfoundry.com/redirect/#{@client_id}"
    response_type = "token"
    response_type = "#{response_type} id_token" if scope && (scope.include? "openid")
    uri = authorize_path_args(response_type, redir_uri, scope, state = random_state)

    # the accept header is only here so the uaa will issue error replies in json to aid debugging
    headers = {'content-type' => FORM_UTF8, 'accept' => JSON_UTF8 }
    body = Util.encode_form(credentials.merge(source: 'credentials'))
    status, body, headers = request(@target, :post, uri, body, headers)
    raise BadResponse, "status #{status}" unless status == 302
    req_uri, reply_uri = URI.parse(redir_uri), URI.parse(headers['location'])
    fragment, reply_uri.fragment = reply_uri.fragment, nil
    raise BadResponse, "bad location header" unless req_uri == reply_uri
    parse_implicit_params(fragment, state)
  rescue URI::Error => e
    raise BadResponse, "bad location header in reply: #{e.message}"
  end

  # Constructs a uri that the client is to return to the browser to direct
  # the user to the authorization server to get an authcode.
  # @param [String] redirect_uri (see #authcode_uri)
  # @return [String]
  def implicit_uri(redirect_uri, scope = nil)
    response_type = "token"
    response_type = "#{response_type} id_token" if scope && (scope.include? "openid")
    @target + authorize_path_args(response_type, redirect_uri, scope)
  end

  # Gets a token via an implicit grant.
  # @param [String] implicit_uri must be from a previous call to
  #   {#implicit_uri}, contains state used to validate the contents of the
  #   reply from the server.
  # @param [String] callback_fragment must be the fragment portion of the URL
  #   received by the user's browser after the server redirects back to the
  #   +redirect_uri+ that was given to {#implicit_uri}. How the application
  #   gets the contents of the fragment is application specific -- usually
  #   some javascript in the page at the +redirect_uri+.
  # @see http://tools.ietf.org/html/rfc6749#section-4.2
  # @return [TokenInfo]
  def implicit_grant(implicit_uri, callback_fragment)
    in_params = Util.decode_form(URI.parse(implicit_uri).query)
    unless in_params['state'] && in_params['redirect_uri']
      raise ArgumentError, "redirect must happen before implicit grant"
    end
    parse_implicit_params(callback_fragment, in_params['state'])
  end

  # A UAA extension to OAuth2 that allows a client to pre-authenticate a
  # user at the start of an authorization code flow. By passing in the
  # user's credentials the server can establish a session with the user's
  # browser without reprompting for authentication. This is useful for
  # user account management apps so that they can create a user account,
  # or reset a password for the user, without requiring the user to type
  # in their credentials again.
  # @param [String] credentials (see #implicit_grant_with_creds)
  # @param [String] redirect_uri (see #authcode_uri)
  # @return (see #authcode_uri)
  def autologin_uri(redirect_uri, credentials, scope = nil)
    headers = {'content-type' => FORM_UTF8, 'accept' => JSON_UTF8,
        'authorization' => Http.basic_auth(@client_id, @client_secret) }
    body = Util.encode_form(credentials)
    reply = json_parse_reply(nil, *request(@target, :post, "/autologin", body, headers))
    raise BadResponse, "no autologin code in reply" unless reply['code']
    @target + authorize_path_args('code', redirect_uri, scope,
        random_state, code: reply['code'])
  end

  # Constructs a uri that the client is to return to the browser to direct
  # the user to the authorization server to get an authcode.
  # @param [String] redirect_uri is embedded in the returned uri so the server
  #   can redirect the user back to the caller's endpoint.
  # @return [String] uri which
  def authcode_uri(redirect_uri, scope = nil)
    @target + authorize_path_args('code', redirect_uri, scope)
  end

  # Uses the instance client credentials in addition to +callback_query+
  # to get a token via the authorization code grant.
  # @param [String] authcode_uri must be from a previous call to {#authcode_uri}
  #   and contains state used to validate the contents of the reply from the
  #   server.
  # @param [String] callback_query must be the query portion of the URL
  #   received by the client after the user's browser is redirected back from
  #   the server. It contains the authorization code.
  # @see http://tools.ietf.org/html/rfc6749#section-4.1
  # @return [TokenInfo]
  def authcode_grant(authcode_uri, callback_query)
    ac_params = Util.decode_form(URI.parse(authcode_uri).query)
    unless ac_params['state'] && ac_params['redirect_uri']
      raise ArgumentError, "authcode redirect must happen before authcode grant"
    end
    begin
      params = Util.decode_form(callback_query)
      authcode = params['code']
      raise BadResponse unless params['state'] == ac_params['state'] && authcode
    rescue URI::InvalidURIError, ArgumentError, BadResponse
      raise BadResponse, "received invalid response from target #{@target}"
    end
    if not @code_verifier.nil?
      request_token(grant_type: 'authorization_code', code: authcode,
          redirect_uri: ac_params['redirect_uri'], code_verifier: @code_verifier)
    else
      request_token(grant_type: 'authorization_code', code: authcode,
                    redirect_uri: ac_params['redirect_uri'])
    end
  end

  # Generates a random verifier for PKCE usage
  def get_verifier
    if not @code_verifier.nil?
      @verifier = @code_verifier
    else
      @verifier ||= SecureRandom.base64(96).tr("+/", "-_").tr("=", "")
    end
  end

  # Calculates the challenge from code_verifier
  def get_challenge
    @challenge ||= Digest::SHA256.base64digest(get_verifier).tr("+/", "-_").tr("=", "")
  end

  # Uses the instance client credentials in addition to the +username+
  # and +password+ to get a token via the owner password grant.
  # See {http://tools.ietf.org/html/rfc6749#section-4.3}.
  # @return [TokenInfo]
  def owner_password_grant(username, password, scope = nil)
    request_token(grant_type: 'password', username: username,
        password: password, scope: scope)
  end

  # Uses a one-time passcode obtained from the UAA to get a
  # token.
  # @return [TokenInfo]
  def passcode_grant(passcode, scope = nil)
    request_token(grant_type: 'password', passcode: passcode, scope: scope)
  end

  # Gets an access token with the user credentials used for authentication
  # via the owner password grant.
  # See {http://tools.ietf.org/html/rfc6749#section-4.3}.
  # @param credentials should be an object such as a hash that can be converted
  #   to a json representation of the credential name/value pairs corresponding to
  #   the keys retrieved by {#prompts}.
  # @return [TokenInfo]
  def owner_password_credentials_grant(credentials)
    credentials[:grant_type] = 'password'
    request_token(credentials)
  end

  # Uses the instance client credentials to get a token with a client
  # credentials grant. See http://tools.ietf.org/html/rfc6749#section-4.4
  # @return [TokenInfo]
  def client_credentials_grant(scope = nil)
    request_token(grant_type: 'client_credentials', scope: scope)
  end

  # Uses the instance client credentials and the given +refresh_token+ to get
  # a new access token. See http://tools.ietf.org/html/rfc6749#section-6
  # @return [TokenInfo] which may include a new refresh token as well as an access token.
  def refresh_token_grant(refresh_token, scope = nil)
    request_token(grant_type: 'refresh_token', refresh_token: refresh_token, scope: scope)
  end

end

end

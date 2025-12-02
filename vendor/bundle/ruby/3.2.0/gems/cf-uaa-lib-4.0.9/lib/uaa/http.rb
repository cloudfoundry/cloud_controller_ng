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

require 'mutex_m'
require 'base64'
require 'uaa/util'
require 'httpclient'

module CF::UAA

# Indicates URL for the target is bad or not accessible.
class BadTarget < UAAError; end

# Indicates invalid SSL Certification for the target.
class SSLException < UAAError; end

# Indicates the resource within the target server was not found.
class NotFound < UAAError; end

# Indicates a syntax error in a response from the UAA, e.g. missing required response field.
class BadResponse < UAAError; end

# Indicates an error from the http client stack.
class HTTPException < UAAError; end

# An application level error from the UAA which includes error info in the reply.
class TargetError < UAAError
  attr_reader :info
  def initialize(error_info = {})
    @info = error_info
  end
end

# Indicates a token is malformed or expired.
class InvalidToken < TargetError; end

# Utility accessors and methods for objects that want to access JSON web APIs.
module Http

  def self.included(base)
    base.class_eval do
      attr_reader :skip_ssl_validation, :ssl_ca_file, :ssl_cert_store, :http_timeout
    end
  end

  def initialize_http_options(options)
    @skip_ssl_validation = options[:skip_ssl_validation]
    @ssl_ca_file = options[:ssl_ca_file]
    @ssl_cert_store = options[:ssl_cert_store]
    @http_timeout = options[:http_timeout]
  end

  # Sets the current logger instance to recieve error messages.
  # @param [Logger] logr
  # @return [Logger]
  def logger=(logr); @logger = logr end

  # The current logger or {Util.default_logger} if none has been set.
  # @return [Logger]
  def logger ; @logger || Util.default_logger end

  # Indicates if the current logger is set to +:trace+ level.
  # @return [Boolean]
  def trace? ; (lgr = logger).respond_to?(:trace?) && lgr.trace? end

  # Sets a handler for outgoing http requests. If no handler is set, an
  # internal cache of net/http connections is used. Arguments to the handler
  # are url, method, body, headers.
  # @param [Proc] blk handler block
  # @return [nil]
  def set_request_handler(&blk) @req_handler = blk; nil end

  # Constructs an http basic authentication header.
  # @return [String]
  def self.basic_auth(name, password)
    str = "#{name}:#{password}"
    'Basic ' + (Base64.respond_to?(:strict_encode64)?
        Base64.strict_encode64(str): [str].pack('m').gsub(/\n/, ''))
  end

  JSON_UTF8 = 'application/json;charset=utf-8'
  FORM_UTF8 = 'application/x-www-form-urlencoded;charset=utf-8'

  private

  def json_get(target, path = nil, style = nil, headers = {})
    raise ArgumentError unless style.nil? || style.is_a?(Symbol)
    json_parse_reply(style, *http_get(target, path, headers.merge('accept' => JSON_UTF8)))
  end

  def json_post(target, path, body, headers = {})
    http_post(target, path, Util.json(body), headers.merge('content-type' => JSON_UTF8))
  end

  def json_put(target, path, body, headers = {})
    http_put(target, path, Util.json(body), headers.merge('content-type' => JSON_UTF8))
  end

  def json_patch(target, path, body, headers = {})
    http_patch(target, path, Util.json(body), headers.merge('content-type' => JSON_UTF8))
  end

  def json_parse_reply(style, status, body, headers)
    raise ArgumentError unless style.nil? || style.is_a?(Symbol)
    unless [200, 201, 204, 400, 401, 403, 409, 422].include? status
      raise (status == 404 ? NotFound : BadResponse), "invalid status response: #{status}"
    end
    if body && !body.empty? && (status == 204 || headers.nil? ||
          headers['content-type'] !~ /application\/json/i)
      raise BadResponse, 'received invalid response content or type'
    end
    parsed_reply = Util.json_parse(body, style)
    if status >= 400
      raise parsed_reply && parsed_reply['error'] == 'invalid_token' ?
          InvalidToken.new(parsed_reply) : TargetError.new(parsed_reply), 'error response'
    end
    parsed_reply
  rescue DecodeError
    raise BadResponse, 'invalid JSON response'
  end

  def http_get(target, path = nil, headers = {}) request(target, :get, path, nil, headers) end
  def http_post(target, path, body, headers = {}) request(target, :post, path, body, headers) end
  def http_put(target, path, body, headers = {}) request(target, :put, path, body, headers) end
  def http_patch(target, path, body, headers = {}) request(target, :patch, path, body, headers) end

  def http_delete(target, path, authorization, zone = nil)
    hdrs = { 'authorization' => authorization }
    hdrs['X-Identity-Zone-Subdomain'] = zone if zone
    status = request(target, :delete, path, nil, hdrs)[0]
    unless [200, 204].include?(status)
      raise (status == 404 ? NotFound : BadResponse), "invalid response from #{path}: #{status}"
    end
  end

  def request(target, method, path, body = nil, headers = {})
    headers['accept'] = headers['content-type'] if headers['content-type'] && !headers['accept']
    url = "#{target}#{path}"

    logger.debug { "--->\nrequest: #{method} #{url}\n" +
        "headers: #{headers}\n#{'body: ' + Util.truncate(body.to_s, trace? ? 50000 : 50) if body}" }
    status, body, headers = @req_handler ? @req_handler.call(url, method, body, headers) :
        net_http_request(url, method, body, headers)
    logger.debug { "<---\nresponse: #{status}\nheaders: #{headers}\n" +
        "#{'body: ' + Util.truncate(body.to_s, trace? ? 50000: 50) if body}" }

    [status, body, headers]

  rescue Exception => e
    logger.debug { "<---- no response due to exception: #{e.inspect}" }
    raise e
  end

  def net_http_request(url, method, body, headers)
    uri = URI.parse(url)
    http = http_request(uri)
    headers['content-length'] = body.length.to_s if body
    case method
      when :get, :delete
        response = http.send(method, uri, nil, headers)
      when :post, :put, :patch
        response = http.send(method, uri, body, headers)
      else
        raise ArgumentError
    end

    unless response.status
      raise HTTPException.new "Can't parse response from the server #{response.content}"
    end
    response_headers = {}
    response.header.all.each { |k, v| response_headers[k.downcase] = v }
    return [response.status.to_i, response.content, response_headers]
  rescue OpenSSL::SSL::SSLError => e
    raise SSLException, "Invalid SSL Cert for #{url}. Use '--skip-ssl-validation' to continue with an insecure target"
  rescue URI::Error, SocketError, SystemCallError => e
    raise BadTarget, "error: #{e.message}"
  rescue HTTPClient::ConnectTimeoutError => e
    raise HTTPException.new "http timeout"
  end

  def http_request(uri)
    cache_key = URI.join(uri.to_s, '/')
    @http_cache ||= {}
    return @http_cache[cache_key] if @http_cache[cache_key]

    if uri.is_a?(URI::HTTPS)
      http = HTTPClient.new.tap do |c|
        if skip_ssl_validation
          c.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        elsif ssl_ca_file
          c.ssl_config.set_trust_ca File.expand_path(ssl_ca_file)
          c.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
        elsif ssl_cert_store
          c.ssl_config.cert_store = ssl_cert_store
          c.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
        else
          c.ssl_config.set_default_paths
        end
      end
    else
      http = HTTPClient.new
    end

    if http_timeout
      http.connect_timeout = http_timeout
      http.send_timeout = http_timeout
      http.receive_timeout = http_timeout
    end

    @http_cache[cache_key] = http
  end

end

end

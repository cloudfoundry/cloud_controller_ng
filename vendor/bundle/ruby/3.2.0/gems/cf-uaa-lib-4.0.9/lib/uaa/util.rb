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

require 'json'
require 'base64'
require 'logger'
require 'uri'

# Cloud Foundry namespace
module CF
  # Namespace for User Account and Authentication service
  module UAA end
end

class Logger # @private
  Severity::TRACE = Severity::DEBUG - 1
  def trace(progname, &blk); add(Logger::Severity::TRACE, nil, progname, &blk) end
  def trace? ; @level <= Logger::Severity::TRACE end
end

module CF::UAA

# Useful parent class. All CF::UAA exceptions are derived from this.
class UAAError < RuntimeError; end

# Indicates an authentication error.
class AuthError < UAAError; end

# Indicates an error occurred decoding a token, base64 decoding, or JSON.
class DecodeError < UAAError; end

# Helper functions useful to the UAA client APIs
class Util

  # General method to transform a hash key to a given style. Useful when
  # dealing with HTTP headers and various protocol tags that tend to contain
  # '-' characters and are case-insensitive and want to use them as keys in
  # ruby hashes. Useful for dealing with {http://www.simplecloud.info/ SCIM}
  # case-insensitive attribute names to normalize all attribute names (downcase).
  #
  # @param [String, Symbol] key current key
  # @param [Symbol] style can be sym, downsym, down, str, [un]dash, [un]camel, nil, none
  # @return [String, Symbol] new key
  def self.hash_key(key, style)
    case style
    when nil, :none then key
    when :downsym then key.to_s.downcase.to_sym
    when :sym then key.to_sym
    when :str then key.to_s
    when :down then key.to_s.downcase
    when :dash then key.to_s.downcase.tr('_', '-')
    when :undash then key.to_s.downcase.tr('-', '_').to_sym
    when :uncamel then key.to_s.gsub(/([A-Z])([^A-Z]*)/,'_\1\2').downcase.to_sym
    when :camel then key.to_s.gsub(/(_[a-z])([^_]*)/) { $1[1].upcase + $2 }
    else raise ArgumentError, "unknown hash key style: #{style}"
    end
  end

  # Modifies obj in place changing any hash keys to style. Recursively modifies
  # subordinate hashes.
  # @param style (see Util.hash_key)
  # @return modified obj
  def self.hash_keys!(obj, style = nil)
    return obj if style == :none
    return obj.each {|o| hash_keys!(o, style)} if obj.is_a? Array
    return obj unless obj.is_a? Hash
    newkeys, nk = {}, nil
    obj.delete_if { |k, v|
      hash_keys!(v, style)
      newkeys[nk] = v unless (nk = hash_key(k, style)) == k
      nk != k
    }
    obj.merge!(newkeys)
  end

  # Makes a new copy of obj with hash keys to style. Recursively modifies
  # subordinate hashes.
  # @param style (see Util.hash_key)
  # @return obj or new object if hash keys were changed
  def self.hash_keys(obj, style = nil)
    return obj.collect {|o| hash_keys(o, style)} if obj.is_a? Array
    return obj unless obj.is_a? Hash
    obj.each_with_object({}) {|(k, v), h|
      h[hash_key(k, style)] = hash_keys(v, style)
    }
  end

  # handle ruby 1.8.7 compatibility for form encoding
  if URI.respond_to?(:encode_www_form_component)
    def self.encode_component(str) URI.encode_www_form_component(str) end #@private
    def self.decode_component(str) URI.decode_www_form_component(str) end #@private
  else
    def self.encode_component(str) # @private
      str.to_s.gsub(/([^ a-zA-Z0-9*_.-]+)/) {
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      }.tr(' ', '+')
    end
    def self.decode_component(str) # @private
      str.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/) {[$1.delete('%')].pack('H*')}
    end
  end

  # Takes an x-www-form-urlencoded string and returns a hash of utf-8 key/value
  # pairs. Useful for OAuth parameters. Raises ArgumentError if a key occurs
  # more than once, which is a restriction of OAuth query strings.
  # OAuth parameters are case sensitive, scim parameters are case-insensitive.
  # @see http://tools.ietf.org/html/rfc6749#section-3.1
  # @param [String] url_encoded_pairs in an x-www-form-urlencoded string
  # @param style (see Util.hash_key)
  # @return [Hash] of key value pairs
  def self.decode_form(url_encoded_pairs, style = nil)
    pairs = {}
    url_encoded_pairs.split(/[&;]/).each do |pair|
      k, v = pair.split('=', 2).collect { |v| decode_component(v) }
      raise "duplicate keys in form parameters" if pairs.key?(k = hash_key(k, style))
      pairs[k] = v
    end
    pairs
  rescue Exception => e
    raise ArgumentError, e.message
  end

  # Encode an object into x-www-form-urlencoded string suitable for oauth2.
  # @note that ruby 1.9.3 converts form components to utf-8. Ruby 1.8.7
  #   users must ensure all data is in utf-8 format before passing to form encode.
  # @param [Hash] obj a hash of key/value pairs to be encoded.
  # @see http://tools.ietf.org/html/rfc6749#section-3.1
  def self.encode_form(obj)
    obj.map {|k, v| encode_component(k) << '=' << encode_component(v)}.join('&')
  end

  # Converts +obj+ to JSON
  # @return [String] obj in JSON form.
  def self.json(obj) JSON.dump(obj) end

  # Converts +obj+ to nicely formatted JSON
  # @return [String] obj in formatted json
  def self.json_pretty(obj) JSON.pretty_generate(obj) end

  # Converts +obj+ to a URL-safe base 64 encoded string
  # @return [String]
  def self.json_encode64(obj = {}) encode64(json(obj)) end

  # Decodes base64 encoding of JSON data.
  # @param [String] str
  # @param style (see Util.hash_key)
  # @return [Hash]
  def self.json_decode64(str, style = nil) json_parse(decode64(str), style) end

  # Encodes +obj+ as a URL-safe base 64 encoded string, with trailing padding removed.
  # @return [String]
  def self.encode64(obj)
    str = Base64.respond_to?(:urlsafe_encode64)? Base64.urlsafe_encode64(obj):
        [obj].pack("m").tr("+/", "-_")
    str.gsub!(/(\n|=*$)/, '')
    str
  end

  # Decodes a URL-safe base 64 encoded string. Adds padding if necessary.
  # @return [String] decoded string
  def self.decode64(str)
    return unless str
    pad = str.length % 4
    str = str + '=' * (4 - pad) if pad > 0
    Base64.respond_to?(:urlsafe_decode64) ?
        Base64.urlsafe_decode64(str) : Base64.decode64(str.tr('-_', '+/'))
  rescue ArgumentError
    raise DecodeError, "invalid base64 encoding"
  end

  # Parses a JSON string.
  # @param style (see Util.hash_key)
  # @return [Hash] parsed data
  def self.json_parse(str, style = nil)
    hash_keys!(JSON.parse(str), style) if str && !str.empty?
  rescue Exception
    raise DecodeError, "json decoding error"
  end

  # Converts obj to a string and truncates if over limit.
  # @return [String]
  def self.truncate(obj, limit = 50)
    return obj.to_s if limit == 0
    limit = limit < 5 ? 1 : limit - 4
    str = obj.to_s[0..limit]
    str.length > limit ? str + '...': str
  end

  # Converts common input formats into array of strings.
  # Many parameters in these classes can be given as arrays, or as a list of
  # arguments separated by spaces or commas. This method handles the possible
  # inputs and returns an array of strings.
  # @return [Array<String>]
  def self.arglist(arg, default_arg = nil)
    arg = default_arg unless arg
    return arg if arg.nil? || arg.respond_to?(:join)
    raise ArgumentError, "arg must be Array or space|comma delimited strings" unless arg.respond_to?(:split)
    arg.split(/[\s\,]+/).reject { |e| e.empty? }
  end

  # Joins arrays of strings into a single string. Reverse of {Util.arglist}.
  # @param [Object, #join] arg
  # @param [String] delim delimiter to put between strings.
  # @return [String]
  def self.strlist(arg, delim = ' ')
    arg.respond_to?(:join) ? arg.join(delim) : arg.to_s if arg
  end

  # Set the default logger used by the higher level classes.
  # @param [String, Symbol] level such as info, debug trace.
  # @param [IO] sink output for log messages, defaults to $stdout
  # @return [Logger]
  def self.default_logger(level = nil, sink = nil)
    if sink || !@default_logger
      @default_logger = Logger.new(sink || $stdout)
      level = :info unless level
      @default_logger.formatter = Proc.new { |severity, time, pname, msg| msg }
    end
    @default_logger.level = Logger::Severity.const_get(level.to_s.upcase) if level
    @default_logger
  end

end

end

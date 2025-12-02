#-------------------------------------------------------------------------
# # Copyright (c) Microsoft and contributors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------
require 'digest/md5'
require 'base64'
require 'net/http'
require 'time'

require 'azure/core/version'
require 'azure/core/http/http_response'
require 'azure/core/http/retry_policy'
require 'azure/core/default'
require 'azure/http_response_helper'

module Azure
  module Core
    module Http
      # Represents a HTTP request can perform synchronous queries to a
      # HTTP server, returning a HttpResponse
      class HttpRequest
        include Azure::HttpResponseHelper
        alias_method :_method, :method

        # The HTTP method to use (:get, :post, :put, :delete, etc...)
        attr_accessor :method

        # The URI of the HTTP endpoint to query
        attr_accessor :uri

        # The header values as a Hash
        attr_accessor :headers

        # The body of the request (IO or String)
        attr_accessor :body

        # Azure client which contains configuration context and http agents
        # @return [Azure::Client]
        attr_accessor :client
        
        # The http filter
        attr_accessor :has_retry_filter

        # Public: Create the HttpRequest
        #
        # @param method   [Symbol] The HTTP method to use (:get, :post, :put, :del, etc...)
        # @param uri      [URI] The URI of the HTTP endpoint to query
        # @param options_or_body  [Hash|IO|String] The request options including {:client, :body} or raw body only
        def initialize(method, uri, options_or_body = {})
          options ||= unless options_or_body.is_a?(Hash)
                        {body: options_or_body}
                      end || options_or_body || {}

          @method = method
          @uri = if uri.is_a?(String)
                   URI.parse(uri)
                 else
                   uri
                 end

          @client = options[:client] || Azure

          self.headers = default_headers(options[:current_time] || Time.now.httpdate).merge(options[:headers] || {})
          self.body = options[:body]
        end

        # Public: Applies a HttpFilter to the HTTP Pipeline
        #
        # filter - Any object that responds to .call(req, _next) and
        #          returns a HttpResponse eg. HttpFilter, Proc,
        #          lambda, etc. (optional)
        #
        # options - The options that are used when call Azure::Core::FilteredService.call.
        #           It can be used by retry policies to determine changes in the retry.
        #
        # &block - An inline block may be used instead of a filter
        #
        #          example:
        #
        #             request.with_filter do |req, _next|
        #               _next.call
        #             end
        #
        # NOTE:
        #
        # The code block provided must call _next or the filter pipeline
        # will not complete and the HTTP request will never execute
        #
        def with_filter(filter=nil, options={}, &block)
          filter = filter || block
          if filter
            is_retry_policy = filter.is_a?(Azure::Core::Http::RetryPolicy)
            filter.retry_data[:request_options] = options if is_retry_policy
            @has_retry_filter ||= is_retry_policy
            
            original_call = self._method(:call)

            # support 1.8.7 (define_singleton_method doesn't exist until 1.9.1)
            filter_call = Proc.new do
              filter.call(self, original_call)
            end
            k = class << self;
              self;
            end
            if k.method_defined? :define_singleton_method
              self.define_singleton_method(:call, filter_call)
            else
              k.send(:define_method, :call, filter_call)
            end
          end
        end

        # Build a default headers Hash
        def default_headers(current_time)
          {}.tap do |def_headers|
            def_headers['User-Agent'] = Azure::Core::Default::USER_AGENT
            def_headers['x-ms-date'] = current_time
            def_headers['x-ms-version'] = '2014-02-14'
            def_headers['DataServiceVersion'] = '1.0;NetFx'
            def_headers['MaxDataServiceVersion'] = '3.0;NetFx'
            def_headers['Content-Type'] = 'application/atom+xml; charset=utf-8'
          end
        end

        def http_setup
          @client.agents(uri)
        end

        def body=(body)
          @body = body
          apply_body_headers
        end

        # Sends request to HTTP server and returns a HttpResponse
        #
        # @return [HttpResponse]
        def call
          conn = http_setup
          res = set_up_response(method.to_sym, uri, conn, headers ,body)

          response = HttpResponse.new(res)
          response.uri = uri
          raise response.error if !response.success? && !@has_retry_filter
          response
        end

        private

        def apply_body_headers
          return headers['Content-Length'] = '0' unless body

          return apply_io_headers        if IO === body
          return apply_string_io_headers if StringIO === body
          return apply_miscellaneous_headers
        end

        def apply_io_headers
          headers['Content-Length'] = body.size.to_s if body.respond_to?('size')
          if headers['Content-Length'].nil?
            raise ArgumentError, '\'Content-Length\' must be defined if size cannot be obtained from body IO.'
          end
          headers['Content-MD5'] = Digest::MD5.file(body.path).base64digest unless headers['Content-MD5']
        end

        def apply_string_io_headers
          headers['Content-Length'] = body.size.to_s
          unless headers['Content-MD5']
            headers['Content-MD5'] = Digest::MD5.new.tap do |checksum|
                                       while chunk = body.read(5242880)
                                         checksum << chunk
                                       end
                                       body.rewind
                                     end.base64digest
          end
        end

        def apply_miscellaneous_headers
          headers['Content-Length'] = body.bytesize.to_s
          headers['Content-MD5'] = Base64.strict_encode64(Digest::MD5.digest(body)) unless headers['Content-MD5']
        end
      end
    end
  end
end

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
require 'azure/core/error'
require 'nokogiri'
require 'json'

module Azure
  module Core
    module Http
      # Public: Class for handling all HTTP response errors
      class HTTPError < Azure::Core::Error

        # Public: Detail of the response
        #
        # Returns an Azure::Core::Http::HttpResponse object
        attr :http_response

        # Public: The request URI
        #
        # Returns a String
        attr :uri

        # Public: The HTTP status code of this error
        #
        # Returns a Fixnum
        attr :status_code

        # Public: The type of error
        #
        # http://msdn.microsoft.com/en-us/library/azure/dd179357
        #
        # Returns a String
        attr :type

        # Public: Description of the error
        #
        # Returns a String
        attr :description

        # Public: Detail of the error
        #
        # Returns a String
        attr :detail

        # Public: The header name whose value is invalid
        #
        # Returns a String
        attr :header

        # Public: The invalid header value
        #
        # Returns a String
        attr :header_value

        # Public: Initialize an error
        #
        # http_response - An Azure::Core::HttpResponse
        def initialize(http_response)
          @http_response = http_response
          @uri = http_response.uri
          @status_code = http_response.status_code
          parse_response
          # Use reason phrase as the description if description is empty
          @description = http_response.reason_phrase if (@description.nil? || @description.empty?) && http_response.reason_phrase
          super("#{type} (#{status_code}): #{description}")
        end

        # Extract the relevant information from the response's body. If the response
        # body is not an XML, we return an 'Unknown' error with the entire body as
        # the description
        #
        # Returns nothing
        def parse_response
          if @http_response.body && @http_response.respond_to?(:headers) && @http_response.headers['Content-Type']
            if @http_response.headers['Content-Type'].include?('xml')
              parse_xml_response
            elsif @http_response.headers['Content-Type'].include?('json')
              parse_json_response
            end
          else
            parse_unknown_response
          end
        end

        def parse_xml_response
          document = Nokogiri.Slop(@http_response.body)

          @type = document.css('code').first.text if document.css('code').any?
          @type = document.css('Code').first.text if document.css('Code').any?
          @description = document.css('message').first.text if document.css('message').any?
          @description = document.css('Message').first.text if document.css('Message').any?
          @header = document.css('headername').first.text if document.css('headername').any?
          @header = document.css('HeaderName').first.text if document.css('HeaderName').any?
          @header_value = document.css('headervalue').first.text if document.css('headervalue').any?
          @header_value = document.css('HeaderValue').first.text if document.css('HeaderValue').any?

          # service bus uses detail instead of message
          @detail = document.css('detail').first.text if document.css('detail').any?
          @detail = document.css('Detail').first.text if document.css('Detail').any?
        end

        def parse_json_response
          odata_error = JSON.parse(@http_response.body)['odata.error']
          @type = odata_error['code']
          @description = odata_error['message']['value']
        end

        def parse_unknown_response
          @type = 'Unknown'
          if @http_response.body
            @description = "#{@http_response.body.strip}"
          end
        end

        def inspect
          string = "#<#{self.class.name}:#{self.object_id} "
          fields = self.instance_variables.map{|field| "#{field}: #{self.send(field.to_s.delete("@")).inspect}"}
          string << fields.join(", ") << ">"
        end
      end
    end
  end
end

# -*- encoding: utf-8 -*-

require 'nokogiri'

module Aliyun
  module STS

    # ServerError represents exceptions from the STS
    # service. i.e. Client receives a HTTP response whose status is
    # NOT OK. #message provides the error message and #to_s gives
    # detailed information probably including the STS request id.
    class ServerError < Common::Exception

      attr_reader :http_code, :error_code, :message, :request_id

      def initialize(response)
        @http_code = response.code
        @attrs = {}

        doc = Nokogiri::XML(response.body) do |config|
          config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
        end rescue nil

        if doc and doc.root
          doc.root.children.each do |n|
            @attrs[n.name] = n.text
          end
        end

        @error_code = @attrs['Code']
        @message = @attrs['Message']
        @request_id = @attrs['RequestId']
      end

      def message
        msg = @attrs['Message'] || "UnknownError[#{http_code}]."
        "#{msg} RequestId: #{request_id}"
      end

      def to_s
        @attrs.merge({'HTTPCode' => @http_code}).map do |k, v|
          [k, v].join(": ")
        end.join(", ")
      end
    end # ServerError

    # ClientError represents client exceptions caused mostly by
    # invalid parameters.
    class ClientError < Common::Exception
    end # ClientError

  end # STS
end # Aliyun

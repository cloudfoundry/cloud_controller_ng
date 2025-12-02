# -*- encoding: utf-8 -*-

require 'nokogiri'

module Aliyun
  module OSS

    ##
    # ServerError represents exceptions from the OSS
    # service. i.e. Client receives a HTTP response whose status is
    # NOT OK. #message provides the error message and #to_s gives
    # detailed information probably including the OSS request id.
    #
    class ServerError < Common::Exception

      attr_reader :http_code, :error_code, :message, :request_id

      def initialize(response)
        @http_code = response.code
        @attrs = {'RequestId' => get_request_id(response)}

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

      private

      def get_request_id(response)
        r = response.headers[:x_oss_request_id] if response.headers
        r.to_s
      end

    end # ServerError

    class CallbackError < ServerError
    end # CallbackError

    ##
    # ClientError represents client exceptions caused mostly by
    # invalid parameters.
    #
    class ClientError < Common::Exception
    end # ClientError

    ##
    # CrcInconsistentError will be raised after a upload operation,
    # when the local crc is inconsistent with the response crc from server. 
    #
    class CrcInconsistentError < Common::Exception; end

    ##
    # FileInconsistentError happens in a resumable upload transaction,
    # when the file to upload has changed during the uploading
    # process. Which means the transaction cannot go on. Or user may
    # have inconsistent data uploaded to OSS.
    #
    class FileInconsistentError < ClientError; end

    ##
    # ObjectInconsistentError happens in a resumable download transaction,
    # when the object to download has changed during the downloading
    # process. Which means the transaction cannot go on. Or user may
    # have inconsistent data downloaded to OSS.
    #
    class ObjectInconsistentError < ClientError; end

    ##
    # PartMissingError happens in a resumable download transaction,
    # when a downloaded part cannot be found as the client tries to
    # resume download. The process cannot go on until the part is
    # restored.
    #
    class PartMissingError < ClientError; end

    ##
    # PartMissingError happens in a resumable download transaction,
    # when a downloaded part has changed(MD5 mismatch) as the client
    # tries to resume download. The process cannot go on until the
    # part is restored.
    #
    class PartInconsistentError < ClientError; end

    ##
    # CheckpointBrokenError happens in a resumable upload/download
    # transaction, when the client finds the checkpoint file has
    # changed(MD5 mismatch) as it tries to resume upload/download. The
    # process cannot go on until the checkpoint file is restored.
    #
    class CheckpointBrokenError < ClientError; end

  end # OSS
end # Aliyun

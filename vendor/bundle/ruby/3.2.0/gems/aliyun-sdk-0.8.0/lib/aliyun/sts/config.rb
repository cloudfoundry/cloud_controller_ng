# -*- encoding: utf-8 -*-

module Aliyun
  module STS

    # A place to store various configurations: credentials, api
    # timeout, retry mechanism, etc
    class Config < Common::Struct::Base

      attrs :access_key_id, :access_key_secret, :endpoint

      def initialize(opts = {})
        super(opts)

        @access_key_id = @access_key_id.strip if @access_key_id
        @access_key_secret = @access_key_secret.strip if @access_key_secret
        @endpoint = @endpoint.strip if @endpoint
      end
    end # Config

  end # STS
end # Aliyun

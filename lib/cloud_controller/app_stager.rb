# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "cloud_controller/multi_response_nats_request"

module VCAP::CloudController
  module AppStager
    class << self
      attr_reader :config, :message_bus, :stager_pool

      def configure(config, message_bus, stager_pool)
        @config = config
        @message_bus = message_bus
        @stager_pool = stager_pool
      end

      def run
        stager_pool.register_subscriptions
      end

      def stage_app(app, options={}, &completion_callback)
        if app.package_hash.nil? || app.package_hash.empty?
          raise Errors::AppPackageInvalid.new("The app package hash is empty")
        end

        task = AppStagerTask.new(config, message_bus, app, stager_pool)
        task.stage(options, &completion_callback)
      end

      def delete_droplet(app)
        Staging.delete_droplet(app.guid)
      end
    end
  end
end

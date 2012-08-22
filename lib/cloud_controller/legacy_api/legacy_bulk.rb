# Copyright (c) 2009-2012 VMware, Inc.
require "sinatra"
require "cloud_controller/rest_controller/base"

module VCAP::CloudController
  class BulkResponse < JsonMessage
    required :results, do
      dict(
        any,
        {
          "id"              => Integer,
          "instances"       => Integer,
          "framework"       => String,
          "runtime"         => String,
          # FIXME: find the enum for this
          "state"           => String,
          "memory"          => Integer,
          "package_state"   => String,
        },
      )
    end
    required :bulk_token, String
  end

  class UserCountsResponse < JsonMessage
    required :counts, do
      {
        "user" => Integer,
      }
    end
  end

  class LegacyBulk < RestController::Base
    class << self
      attr_reader :message_bus, :config

      def configure(config)
        @message_bus = config.fetch(:message_bus, MessageBus)
        @config = config[:bulk_api].merge(
          :cc_partition => config.fetch(:cc_partition),
        )
      end

      def register_subscription
        subject = "cloudcontroller.bulk.credentials.#{config[:cc_partition]}"
        message_bus.subscribe(subject) do |_, reply|
          message_bus.publish(reply, Yajl::Encoder.encode(
            "user"      => config[:auth_user],
            "password"  => config[:auth_password],
          ))
        end
      end

      def credentials
        [
          config[:auth_user],
          config[:auth_password],
        ]
      end

    end

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == self.class.credentials
        raise NotAuthenticated
      end
    end

    def bulk_apps
      batch_size = Integer(params.fetch("batch_size"))
      bulk_token = Yajl::Parser.parse(params.fetch("bulk_token"))
      last_id = Integer(bulk_token.fetch("id", 0))

      apps = {}
      Models::App.where { |app|
        app.id > last_id
      }.limit(batch_size).each do |app|
        hash = {}
        export_attributes = [
          :id,
          :instances,
          :state,
          :memory,
          :package_state,
        ]
        export_attributes.each do |field|
          hash[field.to_s] = app.values.fetch(field)
        end
        hash["runtime"] = app.runtime.name
        hash["framework"] = app.framework.name
        apps[app.id] = hash
      end
      BulkResponse.new(
        :results => apps,
        :bulk_token => Yajl::Encoder.encode( "id" => apps.keys.last ),
      ).encode
    rescue IndexError => e
      raise BadQueryParameter, e.message
    end

    def bulk_user_count
      model = params.fetch("model", "user")
      raise BadQueryParameter, "model" unless model == "user"
      UserCountsResponse.new(
        :counts => {
          "user" => Models::User.count,
        },
      ).encode
    end

    get "/bulk/apps",     :bulk_apps
    get "/bulk/counts",   :bulk_user_count
  end
end

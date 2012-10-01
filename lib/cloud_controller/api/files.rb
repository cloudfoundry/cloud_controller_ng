# Copyright (c) 2009-2011 VMware, Inc.

require "httpclient"
require "redis"

module VCAP::CloudController
  rest_controller :Files do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
    end

    def files(id, instance_id, path = nil, redirect_ok = true)
      app = find_id_and_validate_access(:read, id)

      if path == "logs/staging.log"
        redis_client = Redis.new(:host => @config[:redis][:host],
                                 :port => @config[:redis][:port],
                                 :password => @config[:redis][:password])
        log = StagingTaskLog.fetch(id, redis_client)
        return [HTTP::OK, log.task_log] if log
        return HTTP::NOT_FOUND
      end

      if match = instance_id.match(/^[+]?([0-9]+)$/)
        instance_id = match.captures[0].to_i
      else
        msg = "Request failed for app: #{app.name}, path: #{path || '/'}"
        msg << " as the instance_id: #{instance_id} is not a"
        msg << " non-negative integer."

        raise Errors::FileError.new(msg)
      end

      info = DeaClient.get_file_uri(app, instance_id, path)
      uri = info[:uri]
      file_uri_v2 = info[:file_uri_v2]
      username = password = nil
      if info[:credentials]
        username = info[:credentials][0]
        password = info[:credentials][1]
      end

      uri << "&tail" if params.include?("tail")

      headers = {}
      if range = env["HTTP_RANGE"]
        headers["range"] = range
      end

      http_response = nil
      if !file_uri_v2 || !redirect_ok
        if config[:nginx][:use_nginx]
          basic_auth = {
            "X-Auth" => "Basic #{[[username, password].join(":")].pack("m0")}",
          }
          # TODO: do a "302 Found" when dea_next replaces dea
          x_accel = {"X-Accel-Redirect" => "/internal_redirect/#{uri}"}
          return [200, x_accel.merge(basic_auth), ""]
        else
          http_response = http_get(uri, headers, username, password)
        end
      else
        # TODO: do a "302 Found" here
        if config[:nginx][:use_nginx]
          x_accel = {"X-Accel-Redirect" => "/internal_redirect/#{uri}"}
          return [200, x_accel, ""]
        else
          http_response = http_get(uri, headers, username, password)
        end
      end

      # FIXME if bad things happen during serving the file, we probably
      # shouldn't expose this url
      unless [200, 206].include? http_response.status
        msg = "Request failed for app: #{app.name}, instance: #{instance_id}"
        msg << " as there was an error retrieving the files"
        msg << " from the uri: #{uri}."

        raise Errors::FileError.new(msg)
      end

      [http_response.status, http_response.body]
    end

    def http_get(uri, headers, username, password)
      client = HTTPClient.new
      client.set_auth(nil, username, password) if username && password
      client.get(uri, :header => headers)
    end

    get  "#{path_id}/instances/:instance_id/files", :files
    get  "#{path_id}/instances/:instance_id/files/*", :files
  end
end

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

    def files(id, instance_id, path = nil, v1_api = false)
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

      info = DeaClient.get_file_url(app, instance_id, path)
      url = info[:url]
      credentials = info[:credentials]
      file_uri_v2 = info[:file_uri_v2]

      url << "&tail" if params.include?("tail")

      headers = {}
      if range = env["HTTP_RANGE"]
        headers["range"] = range
      end

      http_response = nil
      if !file_uri_v2 || v1_api
        # TODO: nginx acceleration.
        http_response = http_get(url, credentials[0], credentials[1], headers)
      else
        # TODO: issue file server redirect.
        http_response = http_get(url, nil, nil, headers)
      end

      unless [200, 206].include? http_response.status
        msg = "Request failed for app: #{app.name}, instance: #{instance_id}"
        msg << " as there was an error retrieving the files"
        msg << " from the url: #{url}."

        raise Errors::FileError.new(msg)
      end

      [http_response.status, http_response.body]
    end

    def http_get(url, username, password, headers)
      client = HTTPClient.new
      if username != nil && password != nil
        client.set_auth(nil, username, password)
      end
      client.get(url, :header => headers)
    end

    get  "#{path_id}/instances/:instance_id/files", :files
    get  "#{path_id}/instances/:instance_id/files/*", :files
  end
end

# Copyright (c) 2009-2011 VMware, Inc.

require "httpclient"
require "redis"
require "uri"

module VCAP::CloudController
  rest_controller :Files do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
    end

    def files(id, instance_id, path = nil, opts = {})
      opts = { :allow_redirect => true }.merge(opts)
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

      headers = {}
      if range = env["HTTP_RANGE"]
        headers["Range"] = range
      end

      http_response = nil
      # new VMC and new DEA, let's hand out the directory server url.
      # We sadly still have to serve the files through CC otherwise
      if info.file_uri_v2 && opts[:allow_redirect]
        uri = info.file_uri_v2
        uri = add_tail(uri) if params.include?("tail")
        return [HTTP::FOUND, {"Location" => uri}, nil]
      else
        # We either have an old VMC that doesn't know the tail capability, or
        # that we're serving a file from an old DEA that isn't capable of tail
        # queries
        if config[:nginx][:use_nginx]
          basic_auth = {
            "X-Auth" => "Basic #{[info.credentials.join(":")].pack("m0")}",
          }
          # use the v1 dir server to avoid resolving domain names in nginx
          x_accel = {"X-Accel-Redirect" => "/internal_redirect/#{info.file_uri_v1}"}
          return [200, x_accel.merge(basic_auth), ""]
        end

        http_response = http_get(info.file_uri_v1, headers, info.credentials[0], info.credentials[1])
      end

      # FIXME if bad things happen during serving the file, we probably
      # shouldn't expose this url
      unless [200, 206, 416].include? http_response.status
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

    private
    # @param [String, URI::Generic] uri
    # @return [String] uri with tail=<whatever> added to query string
    def add_tail(uri)
      uri = URI(uri)
      # query is Array of [key, value1, value2...]
      query = URI::decode_www_form(uri.query || "")
      unless query.assoc("tail")
        query.push(["tail", ""])
      end
      uri.query = URI::encode_www_form(query)
      uri.to_s
    end

    get  "#{path_id}/instances/:instance_id/files", :files
    get  "#{path_id}/instances/:instance_id/files/*", :files
  end
end

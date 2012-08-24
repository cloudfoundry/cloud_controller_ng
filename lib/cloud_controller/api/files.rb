# Copyright (c) 2009-2011 VMware, Inc.

require "httpclient"

module VCAP::CloudController
  rest_controller :Files do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
    end

    def files(id, instance_id, path = nil)
      app = find_id_and_validate_access(:read, id)

      begin
        instance_id = Integer(instance_id)
      rescue => e
        msg = "Request failed for app: #{app.name}, path: #{path || '/'}"
        msg << " as the instance_id: #{instance_id} is not a positive integer."

        raise FileError.new(msg)
      end

      url, credentials = DeaClient.get_file_url(app, instance_id, path)
      http_response = http_get(url, credentials[0], credentials[1])

      # TODO: nginx acceleration

      unless http_response.status == 200
        msg = "Request failed for app: #{app.name}, instance: #{instance_id}"
        msg << " as there was an error retrieving the files"
        msg << " from the url: #{url}."

        raise FileError.new(msg)
      end

      [HTTP::OK, http_response.body]
    end

    def http_get(url, username, password)
      client = HTTPClient.new
      client.set_auth(nil, username, password)
      client.get(url)
    end

    get  "#{path_id}/instances/:instance_id/files", :files
    get  "#{path_id}/instances/:instance_id/files/:path", :files
  end
end

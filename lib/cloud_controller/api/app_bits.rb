# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :AppBits do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      full Permissions::CFAdmin
      full Permissions::SpaceDeveloper
    end

    def upload(id)
      app = find_id_and_validate_access(:update, id)

      # TODO: non-nginx support
      ["application_path", "resources"].each do |k|
        raise Errors::AppBitsUploadInvalid.new("missing :#{k}") unless params[k]
      end

      resources = json_param("resources")
      unless resources.kind_of?(Array)
        raise Errors::AppBitsUploadInvalid.new("resources is not an Array")
      end

      # TODO: non-nginx support
      # TODO: validate upload path
      unless path = params["application_path"]
        raise Errors::AppBitsUploadInvalid.new("bad :application")
      end
      uploaded_file = Struct.new(:path).new(path)

      sha1 = AppPackage.to_zip(app.guid, uploaded_file, resources)
      app.package_hash = sha1
      app.save

      HTTP::CREATED
    end

    def json_param(name)
      raw = params[name]
      Yajl::Parser.parse(raw)
    rescue Yajl::ParseError => e
      raise Errors::AppBitsUploadInvalid.new("invalid :#{name}")
    end

    put "#{path_id}/bits", :upload
  end
end

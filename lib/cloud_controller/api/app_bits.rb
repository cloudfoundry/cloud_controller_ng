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

      if config[:nginx][:use_nginx]
        mandatory_params = ["application_path", "resources"]
      else
        mandatory_params = ["application", "resources"]
      end
      mandatory_params.each do |k|
        raise Errors::AppBitsUploadInvalid.new("missing :#{k}") unless params[k]
      end

      resources = json_param("resources")
      unless resources.kind_of?(Array)
        raise Errors::AppBitsUploadInvalid.new("resources is not an Array")
      end

      # TODO: validate upload path
      if config[:nginx][:use_nginx]
        path = params["application_path"]
        uploaded_file = Struct.new(:path).new(path)
      else
        application = params["application"]
        if application.kind_of?(Hash) && application[:tempfile]
          uploaded_file = application[:tempfile]
        else
          raise Errors::AppBitsUploadInvalid.new("bad :application")
        end
      end

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

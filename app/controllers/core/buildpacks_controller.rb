module VCAP::CloudController
  rest_controller :Buildpacks do
    disable_default_routes

    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :name, String
      attribute :url,  String
    end

    define_messages

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)

      if name_errors && name_errors.include?(:unique)
        return Errors::BuildpackNameTaken.new(attributes["name"])
      end

      Errors::BuildpackInvalid.new
    end

    post path, :create

    private

    def after_create(buildpack)
      DeaClient.add_buildpack(buildpack.name, buildpack.url)
    end
  end
end

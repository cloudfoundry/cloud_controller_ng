module VCAP::CloudController
  rest_controller :Buildpacks do
    disable_default_routes

    def add
      raise Errors::NotAuthorized unless user.admin? || roles.admin?

      attributes = Yajl::Parser.parse(body)
      name = attributes["name"]
      url = attributes["url"]

      DeaClient.add_buildpack(name, url)

      [HTTP::CREATED, Yajl::Encoder.encode({buildpack: {name: name}})]
    end

    post "/buildpacks", :add
  end
end

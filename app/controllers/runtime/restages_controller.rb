module VCAP::CloudController
  class RestagesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    post "#{path_guid}/restage", :restage

    def restage(guid)
      app = find_guid_and_validate_access(:read, guid)

      if app.pending?
        raise VCAP::Errors::ApiError.new_from_details("NotStaged")
      end

      app.restage!

      [
          HTTP::CREATED,
          {"Location" => "#{self.class.path}/#{app.guid}"},
          object_renderer.render_json(self.class, app, @opts)
      ]
    end
  end
end

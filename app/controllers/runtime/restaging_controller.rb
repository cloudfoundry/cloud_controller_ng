module VCAP::CloudController
  class RestagingController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    post "#{path_guid}/restage", :restage
    def restage(guid)
      app = find_guid_and_validate_access(:read, guid)

      if app.pending?
        raise VCAP::Errors::ApiError.new_from_details("NotStaged")
      end

      app.mark_for_restaging
      app.save
    end
  end
end

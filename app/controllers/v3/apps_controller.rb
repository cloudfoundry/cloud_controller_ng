module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController

    get '/v3/apps/:guid', :show
    def show(guid)
      app_model = AppModel.find(guid: guid)
      if app_model.nil? || @access_context.cannot?(:read, app_model)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end

      response = {
        guid: guid,
        _links: {
          self: { href: "/v3/apps/#{guid}" },
          processes: { href: "/v3/apps/#{guid}/processes" }
        }
      }.to_json

      [HTTP::OK, response]
    end

  end
end

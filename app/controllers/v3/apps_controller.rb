require 'presenters/v3/app_presenter'

module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController

    get '/v3/apps/:guid', :show
    def show(guid)
      app_model = AppModel.find(guid: guid)

      if app_model.nil? || @access_context.cannot?(:read, app_model)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end

      presenter = AppPresenter.new(app_model)
      [HTTP::OK, presenter.present_json]
    end

    post '/v3/apps', :create
    def create
      creation_opts = MultiJson.load(body).symbolize_keys
      app_model     = AppModel.new(space_guid: creation_opts[:space_guid])

      if @access_context.cannot?(:create, app_model)
        raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
      end

      app_model.save

      presenter = AppPresenter.new(app_model)
      [HTTP::CREATED, presenter.present_json]

    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end
  end
end

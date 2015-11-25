module VCAP::CloudController
  class DropletStageRequestBuilder
    def build(request_body, app_data)
      return build_data_defaults(request_body, app_data)      if request_body['lifecycle']
      return build_lifecycle_defaults(request_body, app_data) if request_body['lifecycle'].nil?
    end

    private

    def build_data_defaults(request_body, app_data)
      request_data = request_body['lifecycle']['data']
      return request_body if request_data.nil? || request_body['lifecycle']['type'] == VCAP::CloudController::PackageModel::DOCKER_TYPE

      request_body['lifecycle']['data']['buildpack'] = default_buildpack(app_data, request_data)
      request_body['lifecycle']['data']['stack'] = default_stack(app_data, request_data)
      request_body
    end

    def build_lifecycle_defaults(request_body, app_data)
      request_body['lifecycle'] = {
        'type' => 'buildpack',
        'data' => {
          'buildpack' => default_buildpack(app_data),
          'stack' => default_stack(app_data)
        }
      }
      request_body
    end

    def default_buildpack(app_data, incoming_data={})
      incoming_data['buildpack'] ? incoming_data['buildpack'] : app_data.buildpack
    end

    def default_stack(app_data, incoming_data={})
      incoming_data['stack'] ? incoming_data['stack'] : app_data.stack
    end
  end
end

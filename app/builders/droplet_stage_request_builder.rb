module VCAP::CloudController
  class DropletStageRequestBuilder
    def build(request, app_data)
      return build_data_defaults(request, app_data)      if request['lifecycle']
      return build_lifecycle_defaults(request, app_data) if request['lifecycle'].nil?
    end

    private

    def build_data_defaults(request, app_data)
      data = request['lifecycle']['data']
      return request if data.nil?

      request['lifecycle']['data']['buildpack'] = default_buildpack(app_data, data)
      request['lifecycle']['data']['stack'] = default_stack(app_data, data)
      request
    end

    def build_lifecycle_defaults(request, app_data)
      request['lifecycle'] = {
        'type' => 'buildpack',
        'data' => {
          'buildpack' => default_buildpack(app_data),
          'stack' => default_stack(app_data)
        }
      }
      request
    end

    def default_buildpack(app_data, incoming_data={})
      incoming_data['buildpack'] ? incoming_data['buildpack'] : app_data.buildpack
    end

    def default_stack(app_data, incoming_data={})
      incoming_data['stack'] ? incoming_data['stack'] : app_data.stack
    end
  end
end

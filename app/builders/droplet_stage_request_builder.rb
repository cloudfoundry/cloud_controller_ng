module VCAP::CloudController
  class DropletStageRequestBuilder
    def build(request, app_data)
      if request['lifecycle']
        data = request['lifecycle']['data']
        if data
          request['lifecycle']['data']['buildpack'] = data['buildpack'] ? data['buildpack'] : app_data.buildpack
          request['lifecycle']['data']['stack'] = data['stack'] ? data['stack'] : app_data.stack
        end
      elsif request['lifecycle'].nil?
        request['lifecycle'] = {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_data.buildpack,
            'stack' => app_data.stack
          }
        }
      end

      request
    end
  end
end

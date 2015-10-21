module VCAP::CloudController
  class AppCreateRequestBuilder
    def build(request)
      if request['lifecycle'] && request['lifecycle']['data']
        request['lifecycle']['data']['buildpack'] = request['lifecycle']['data']['buildpack'] ? request['lifecycle']['data']['buildpack'] : nil
        request['lifecycle']['data']['stack'] = request['lifecycle']['data']['stack'] ? request['lifecycle']['data']['stack'] : Stack.default.name
      elsif request['lifecycle'].nil?
        request['lifecycle'] = default_lifecycle
      end

      request
    end

    private

    def default_lifecycle
      {
        'type' => 'buildpack',
        'data' => {
          'buildpack' => nil,
          'stack' => Stack.default.name
        }
      }
    end
  end
end

class RootController < ActionController::Base
  def v3_root
    render :ok, json: MultiJson.dump(
      {
        links: {
          self:  {
            href: build_api_uri
          },
          tasks: {
            href: build_api_uri(path: '/tasks')
          },
          apps: {
            href: build_api_uri(path: '/apps')
          }
        }
      }, pretty: true)
  end

  private

  def build_api_uri(path: nil)
    my_uri        = URI::HTTP.build(host: VCAP::CloudController::Config.config[:external_domain], path: "/v3#{path}")
    my_uri.scheme = VCAP::CloudController::Config.config[:external_protocol]
    my_uri.to_s
  end
end

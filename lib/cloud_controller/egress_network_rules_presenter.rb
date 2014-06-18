module VCAP::CloudController
  class EgressNetworkRulesPresenter
    def initialize(app_security_groups)
      @app_security_groups = app_security_groups
    end

    def to_array
      @app_security_groups.map do |asg|
        JSON.parse(asg.rules)
      end.flatten
    end
  end
end

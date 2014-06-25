module VCAP::CloudController
  class EgressNetworkRulesPresenter
    def initialize(security_groups)
      @security_groups = security_groups
    end

    def to_array
      @security_groups.map(&:rules).flatten
    end
  end
end

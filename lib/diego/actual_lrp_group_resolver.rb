require 'diego/bbs/bbs'
require 'diego/errors'
require 'diego/lrp_constants'

module Diego
  class ActualLRPGroupResolver
    class ActualLRPGroupError < Diego::Error
    end

    def self.get_lrp(actual_lrp_group)
      if actual_lrp_group.instance.nil? && actual_lrp_group.evacuating.nil?
        raise ActualLRPGroupError.new('missing instance and evacuating on actual lrp group')
      elsif actual_lrp_group.evacuating.nil?
        actual_lrp_group.instance
      elsif actual_lrp_group.instance.nil?
        actual_lrp_group.evacuating
      elsif actual_lrp_group.instance.state == ActualLRPState::RUNNING || actual_lrp_group.instance.state == ActualLRPState::CRASHED
        actual_lrp_group.instance
      else
        actual_lrp_group.evacuating
      end
    end
  end
end

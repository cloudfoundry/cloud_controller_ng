module VCAP::CloudController
  class JobAccess < BaseAccess
    def read?(_)
      has_read_scope? && logged_in?
    end
  end
end

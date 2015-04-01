module VCAP::CloudController
  class Membership
    def initialize(user)
      @user = user
    end

    def developed_spaces
      @user.spaces_dataset.association_join(:organization).where(organization__status: 'active')
    end
  end
end

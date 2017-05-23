module VCAP::CloudController
  class UserAuditInfo
    DATA_UNAVAILABLE = 'UNKNOWN'.freeze

    attr_reader :user_email, :user_name, :user_guid

    def initialize(user_email:, user_name: nil, user_guid:)
      @user_email = user_email || ''
      @user_name  = user_name || ''
      @user_guid  = user_guid
    end

    def self.from_context(context)
      new(
        user_email: context.current_user_email,
        user_name:  context.current_user_name,
        user_guid:  context.current_user.try(:guid)
      )
    end
  end
end

module VCAP::CloudController
  class IncludeRoleUserDecorator
    class << self
      def match?(include_params)
        include_params&.include?('user')
      end

      def decorate(hash, roles)
        hash[:included] ||= {}
        user_guids = roles.map(&:user_guid).uniq
        users = User.where(guid: user_guids).order(:created_at).
                eager(Presenters::V3::UserPresenter.associated_resources).all
        uaa_users = User.uaa_users_info(user_guids)

        hash[:included][:users] = users.map { |user| Presenters::V3::UserPresenter.new(user, uaa_users: uaa_users).to_hash }
        hash
      end
    end
  end
end

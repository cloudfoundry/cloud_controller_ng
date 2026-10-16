module VCAP::CloudController
  class UsernamePopulator
    attr_reader :uaa_client

    def initialize(uaa_client)
      @uaa_client = uaa_client
    end

    def transform(users, _opts={})
      users = Array(users)
      accounts = ServiceAccountModel.where(name: users.select(&:is_oauth_client).map { |user| user.guid.delete_prefix('cf:service-account:') }).all
      account_names = accounts.to_h { |account| [account.client_id, account.name] }
      human_users = users.reject { |user| user.is_oauth_client && account_names.key?(user.guid) }
      username_mapping = human_users.empty? ? {} : uaa_client.usernames_for_ids(human_users.collect(&:guid))
      users.each { |user| user.username = user.is_oauth_client && account_names.key?(user.guid) ? account_names[user.guid] : username_mapping[user.guid] }
    end
  end
end

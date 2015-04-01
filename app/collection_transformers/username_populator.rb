module VCAP::CloudController
  class UsernamePopulator
    attr_reader :uaa_client

    def initialize(uaa_client)
      @uaa_client = uaa_client
    end

    def transform(users, opts={})
      user_ids = users.collect(&:guid)
      username_mapping = uaa_client.usernames_for_ids(user_ids)
      users.each { |user| user.username = username_mapping[user.guid] }
    end
  end
end

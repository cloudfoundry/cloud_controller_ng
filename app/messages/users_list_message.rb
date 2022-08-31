require 'messages/metadata_list_message'

module VCAP::CloudController
  class UsersListMessage < MetadataListMessage
    register_allowed_keys [
      :usernames,
      :partial_usernames,
      :origins
    ]

    validates_with NoAdditionalParamsValidator

    validate :origin_requires_username_or_partial_usernames
    validate :usernames_or_partial_usernames

    validates :usernames, allow_nil: true, array: true
    validates :partial_usernames, allow_nil: true, array: true
    validates :origins, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(usernames partial_usernames origins))
    end

    def origin_requires_username_or_partial_usernames
      if @origins
        unless @usernames || @partial_usernames
          errors.add(:origins, 'filter cannot be provided without usernames or partial_usernames filter.')
        end
      end
    end

    def usernames_or_partial_usernames
      if @usernames && @partial_usernames
        errors.add(:usernames, 'filter cannot be provided with both usernames and partial_usernames filter.')
      end
    end
  end
end

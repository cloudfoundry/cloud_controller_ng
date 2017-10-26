module VCAP::CloudController
  module UaaOriginValidator
    def validate_origin_for_username!(origin, username)
      origins_for_username = @uaa_client.origins_for_username(username)
      if origin.present?
        if !origins_for_username.include?(origin)
          message = "username: '#{username}', origin: '#{origin}'"
          raise CloudController::Errors::ApiError.new_from_details('UserWithOriginNotFound', message)
        end
      elsif origins_for_username.size > 1
        raise CloudController::Errors::ApiError.new_from_details('UserIsInMultipleOrigins',
          origins_for_username.map { |s| "'#{s}'" })
      end
    end
  end
end

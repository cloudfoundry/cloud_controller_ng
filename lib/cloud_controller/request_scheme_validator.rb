module CloudController
  class RequestSchemeValidator
    def validate!(user, roles, config, request)
      return unless user || roles.admin?

      if config[:https_required] && request.scheme != 'https'
        raise CloudController::Errors::ApiError.new_from_details('NotAuthorized')
      end

      if config[:https_required_for_admins] && roles.admin? && request.scheme != 'https'
        raise CloudController::Errors::ApiError.new_from_details('NotAuthorized')
      end
    end
  end
end

require 'fetchers/log_access_fetcher'

module VCAP::CloudController
  class LogAccessController < RestController::BaseController
    get '/internal/v4/log_access/:guid', :lookup
    def lookup(guid)
      check_read_permissions!

      if roles.admin? || roles.admin_read_only? || roles.global_auditor?
        found = LogAccessFetcher.new.app_exists?(guid)
      else
        allowed_space_guids = membership.authorized_space_guids_subquery(Permissions::ROLES_FOR_SPACE_READING)
        found = LogAccessFetcher.new.app_exists_by_space?(guid, allowed_space_guids)
      end

      found ? HTTP::OK : HTTP::NOT_FOUND
    end

    def membership
      @membership ||= Membership.new(current_user)
    end
  end
end

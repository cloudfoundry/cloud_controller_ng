require 'queries/log_access_fetcher'

module VCAP::CloudController
  class LogAccessController < RestController::BaseController
    get '/internal/log_access/:guid', :lookup
    def lookup(guid)
      check_read_permissions!

      if roles.admin?
        found = LogAccessFetcher.new.app_exists?(guid)
      else
        allowed_space_guids = membership.space_guids_for_roles([Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
        found = LogAccessFetcher.new.app_exists_by_space?(guid, allowed_space_guids)
      end

      found ? HTTP::OK : HTTP::NOT_FOUND
    end

    def membership
      @membership ||= Membership.new(current_user)
    end
  end
end

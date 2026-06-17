require 'fetchers/log_access_fetcher'

module VCAP::CloudController
  class LogAccessController < RestController::BaseController
    get '/internal/v4/log_access/:guid', :lookup
    def lookup(guid)
      check_read_permissions!

      if permission_queryer.can_read_globally?
        found = LogAccessFetcher.new.app_exists?(guid)
      else
        allowed_space_guids = permission_queryer.readable_space_guids_query
        found = LogAccessFetcher.new.app_exists_by_space?(guid, allowed_space_guids)
      end

      found ? HTTP::OK : HTTP::NOT_FOUND
    end

    private

    def permission_queryer
      @permission_queryer ||= Permissions.new(SecurityContext.current_user)
    end
  end
end

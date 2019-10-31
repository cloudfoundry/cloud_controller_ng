require 'fetchers/service_offerings_fetcher'

class ServiceOfferingsController < ApplicationController
  def show
    guid = hashed_params[:guid]

    offering = if !current_user
                 ServiceOfferingsFetcher.fetch_one_anonymously(guid)
               elsif permission_queryer.can_read_globally?
                 ServiceOfferingsFetcher.fetch_one(guid)
               else
                 ServiceOfferingsFetcher.fetch_one(guid, org_guids: permission_queryer.readable_org_guids)
               end

    if offering.nil?
      render status: :not_found, json: {}
    else
      render status: :ok, json: { guid: guid }.to_json
    end
  end

  def enforce_authentication?
    return false if action_name == 'show'

    super
  end

  def enforce_read_scope?
    return false if action_name == 'show'

    super
  end
end

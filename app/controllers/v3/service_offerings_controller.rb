require 'fetchers/service_offerings_fetcher'

class ServiceOfferingsController < ApplicationController
  def show
    guid = hashed_params[:guid]

    #service_offering = if permission_queryer.can_read_globally?
    #  fetcher.fetch_one(guid)
    #else
    puts permission_queryer.readable_org_guids
    offering = ServiceOfferingsFetcher.fetch_one(guid, org_guids: permission_queryer.readable_org_guids)
    #end
    # TODO: handle nil


    # offering -> plan -> plan_visibility -> org

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

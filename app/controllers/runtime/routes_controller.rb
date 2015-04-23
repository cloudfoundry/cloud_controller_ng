module VCAP::CloudController
  class RoutesController < RestController::ModelController
    define_attributes do
      attribute :host, String, default: ''
      attribute :path, String, default: nil
      to_one :domain
      to_one :space
      to_many :apps
    end

    query_parameters :host, :domain_guid, :organization_guid, :path

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        return Errors::ApiError.new_from_details('RouteHostTaken', attributes['host'])
      end

      space_errors = e.errors.on(:space)
      if space_errors && space_errors.include?(:total_routes_exceeded)
        return Errors::ApiError.new_from_details('SpaceQuotaTotalRoutesExceeded')
      end

      org_errors = e.errors.on(:organization)
      if org_errors && org_errors.include?(:total_routes_exceeded)
        return Errors::ApiError.new_from_details('OrgQuotaTotalRoutesExceeded')
      end

      path_errors = e.errors.on(:path)
      if path_errors && path_errors.include?(:invalid_path)
        return Errors::ApiError.new_from_details('PathInvalid', attributes['path'])
      end

      Errors::ApiError.new_from_details('RouteInvalid', e.errors.full_messages)
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      org_index = opts[:q].index { |query| query.start_with?('organization_guid:') } if opts[:q]
      if !org_index.nil?
        org_guid = opts[:q][org_index].split(':')[1]
        opts[:q].delete(opts[:q][org_index])

        super(model, ds, qp, opts).
          select_all(:routes).
          left_join(:spaces, id: :routes__space_id).
          left_join(:organizations, id: :spaces__organization_id).
          where(organizations__guid: org_guid)
      else
        super(model, ds, qp, opts)
      end
    end

    get "#{path}/reserved/domain/:domain_guid/host/:host", :route_reserved
    def route_reserved(domain_guid, host)
      validate_access(:reserved, model)
      domain = Domain[guid: domain_guid]
      if domain
        count = Route.where(domain: domain, host: host).count
        return [HTTP::NO_CONTENT, nil] if count > 0
      end
      [HTTP::NOT_FOUND, nil]
    end

    define_messages
    define_routes
  end
end

require 'actions/space_delete'

module VCAP::CloudController
  class OrganizationDelete
    def initialize(space_deleter)
      @space_deleter = space_deleter
    end

    def delete(org_dataset)
      org_dataset.each do |org|
        errs = @space_deleter.delete(org.spaces_dataset)
        return errs unless errs.empty?
        org.destroy
        []
      end
    end

    def timeout_error(dataset)
      org_name = dataset.first.name
      VCAP::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
    end
  end
end

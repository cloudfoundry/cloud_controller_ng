require 'actions/space_delete'

module VCAP::CloudController
  class OrganizationDelete
    def initialize(space_deleter)
      @space_deleter = space_deleter
    end

    def delete(org_dataset)
      org_dataset.all.each do |org|
        errs = @space_deleter.delete(org.spaces_dataset)
        unless errs.empty?
          error_message = errs.map(&:message).join("\n\n")
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
        end
        org.destroy
      end
      []
    end

    def timeout_error(dataset)
      org_name = dataset.first.name
      CloudController::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
    end
  end
end

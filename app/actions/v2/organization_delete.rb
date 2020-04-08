require 'actions/space_delete'
require 'actions/label_delete'
require 'actions/annotation_delete'

module VCAP::CloudController
  module V2
    class OrganizationDelete
      def initialize(space_deleter)
        @space_deleter = space_deleter
      end

      def delete(org_dataset)
        org_dataset.each do |org|
          errs = @space_deleter.delete(org.spaces_dataset)
          unless errs.empty?
            error_message = errs.map(&:message).join("\n\n")
            return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
          end

          Organization.db.transaction do
            org.destroy
          end
        end
      end

      def timeout_error(dataset)
        org_name = dataset.first.name
        CloudController::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
      end
    end
  end
end

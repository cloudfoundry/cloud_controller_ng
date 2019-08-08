module VCAP::CloudController
  class IncludeOrganizationDecorator < IncludeDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(org organization).include?(i) }
      end

      def decorate(hash, spaces)
        hash[:included] ||= {}
        organization_guids = spaces.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids).order(:created_at)
      end

      def association_name
        'organization'
      end

      def association_class
        Organization
      end

      def presenter
        Presenters::V3::OrganizationPresenter
      end
    end
  end
end

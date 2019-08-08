require 'decorators/include_decorator'

module VCAP::CloudController
  class IncludeAppOrganizationDecorator < IncludeDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(org space.organization).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}
        organization_guids = apps.map(&:organization_guid).uniq
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

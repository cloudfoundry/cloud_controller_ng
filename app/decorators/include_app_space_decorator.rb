require 'decorators/include_decorator'

module VCAP::CloudController
  class IncludeAppSpaceDecorator < IncludeDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(space space.organization).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}
        space_guids = apps.map(&:space_guid).uniq
        spaces = Space.where(guid: space_guids)
      end

      def association_name
        'space'
      end

      def association_class
        Space
      end

      def presenter
        Presenters::V3::SpacePresenter
      end
    end
  end
end

module VCAP::CloudController
  class IncludeAppSpaceDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(space space.organization).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}
        space_guids = apps.map(&:space_guid).uniq
        spaces = Space.where(guid: space_guids)

        hash[:included][:spaces] = spaces.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
        hash
      end
    end
  end
end

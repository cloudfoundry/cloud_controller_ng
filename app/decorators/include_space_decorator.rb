module VCAP::CloudController
  class IncludeSpaceDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(space space.organization).include?(i) }
      end

      def decorate(hash, resources)
        hash[:included] ||= {}
        space_guids = resources.map(&:space_guid).uniq
        spaces = Space.where(guid: space_guids).order(:created_at).
                 eager(Presenters::V3::SpacePresenter.associated_resources).all

        hash[:included][:spaces] = spaces.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
        hash
      end
    end
  end
end

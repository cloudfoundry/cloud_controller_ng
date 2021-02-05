module VCAP::CloudController
  class IncludeRoleSpaceDecorator
    class << self
      def match?(include_params)
        include_params&.include?('space')
      end

      def decorate(hash, roles)
        hash[:included] ||= {}
        space_guids = roles.map(&:space_guid).uniq
        spaces = Space.where(guid: space_guids).order(:created_at).
                 eager(Presenters::V3::SpacePresenter.associated_resources).all

        hash[:included][:spaces] = spaces.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
        hash
      end
    end
  end
end

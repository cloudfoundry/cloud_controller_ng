module VCAP::CloudController
  class IncludeRoleSpaceDecorator
    class << self
      def match?(include_params)
        include_params&.include?('space')
      end

      def decorate(hash, roles)
        hash[:included] ||= {}
        space_ids = roles.select(&:for_space?).map(&:space_id).uniq
        unless space_ids.empty?
          spaces = Space.where(id: space_ids).order(:created_at).
                   eager(Presenters::V3::SpacePresenter.associated_resources).all
        end

        hash[:included][:spaces] = spaces&.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash } || []
        hash
      end
    end
  end
end

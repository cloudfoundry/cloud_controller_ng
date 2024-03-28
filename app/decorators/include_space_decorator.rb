module VCAP::CloudController
  class IncludeSpaceDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w[space space.organization].include?(i) }
      end

      def decorate(hash, resources)
        hash[:included] ||= {}
        space_guids = resources.map(&:space_guid).uniq
        spaces_query = Space.where(guid: space_guids).order(:created_at).
                       eager(Presenters::V3::SpacePresenter.associated_resources)
        spaces_query = with_readable_space_guids(spaces_query)

        hash[:included][:spaces] = spaces_query.all.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
        hash
      end

      private

      # This method is used to filter out spaces that the user does not have read access to.
      # An org_auditor can read routes in a space, but not the space itself.
      def with_readable_space_guids(spaces_query)
        permission_queryer = Permissions.new(SecurityContext.current_user)
        return spaces_query if permission_queryer.can_read_globally?

        spaces_query.where(guid: permission_queryer.readable_space_guids_query)
      end
    end
  end
end

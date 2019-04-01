module CloudController
  module Presenters
    module V2
      class UserPresenter < DefaultPresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::User'

        def entity_hash(controller, user, opts, depth, parents, orphans=nil)
          super(controller, user, opts, depth, parents, orphans).merge(user_fields(user))
        end

        def user_fields(user)
          {
            'default_space_guid' => user.default_space_guid,
            'active' => to_bool(user.active),
            'admin' => to_bool(user.admin),
          }
        end

        def to_bool(value)
          case value
          when true
            true
          when false
            false
          when Integer
            value != 0
          else
            raise VCAP::CloudController::Errors::ApiError.new_from_details('DatabaseError')
          end
        end
      end
    end
  end
end

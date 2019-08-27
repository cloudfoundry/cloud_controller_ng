module VCAP::CloudController
  class UserDeleteAction
    def delete(users)
      users.each do |user|
        User.db.transaction do
          user.destroy
        end
      end
      []
    end
  end
end

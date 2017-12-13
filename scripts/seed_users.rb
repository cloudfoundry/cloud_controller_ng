# usage: pipe this script into bin/console on the api vm

NUM_USERS = 5000

org_roles = %w/manager auditor billing_manager/
space_roles = %w/developer manager auditor/


NUM_USERS.times do |i|
  org = Organization.all.sample
  space = org.spaces.sample
  user = User.create(guid: "user-#{i}")
  org.add_user(user)
  org.save
  if space.nil?  || [true, false].sample
    org.send("add_#{org_roles.sample}", user)
  else
    space.send("add_#{space_roles.sample}", user)
  end
end

# User.where(admin: false).all.map(&:destroy)

# For creating a few users with many roles
# 1 users; 20 orgs; 10 spaces per org
# usage: pipe this script into bin/console on the api vm

NUM_ORGS = 20
NUM_SPACES = 10

org_roles = %w/manager auditor billing_manager/
space_roles = %w/developer manager auditor/

user = User.find_or_create(guid: 'seed-role-user')

NUM_ORGS.times do |i|
  org = VCAP::CloudController::Organization.find_or_create(
    name: "seed-role-org-#{i}",
    status: Organization::ACTIVE,
  )
  org_roles.each do |org_role|
    org.add_user(user)
    org.send("add_#{org_role}", user)
  end
  NUM_SPACES.times do |j|
    space = VCAP::CloudController::Space.find_or_create(name: "seed-role-space-#{j}", organization: org)

    space_roles.each do |space_role|
      space.send("add_#{space_role}", user)
    end
  end
end

# User.where(admin: false).all.map(&:destroy)

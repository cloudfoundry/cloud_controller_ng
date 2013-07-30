module VCAP::CloudController
  rest_controller :Events do
    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      to_one :space
    end
  end
end
module ModelCreation
  def make_user_for_org(org)
    user = VCAP::CloudController::User.make
    user.add_organization org
    org.refresh
    user
  end

  def make_domain_for_org(org)
    VCAP::CloudController::PrivateDomain.make(:owning_organization => org)
  end

  def make_user_for_space(space)
    make_user_for_org space.organization
  end

  def make_manager_for_space(space)
    user = make_user_for_org space.organization
    space.add_manager user
    user
  end

  def make_developer_for_space(space)
    user = make_user_for_org space.organization
    space.add_developer user
    user
  end

  def make_auditor_for_space(space)
    user = make_user_for_org(space.organization)
    space.add_auditor(user)
    user
  end

  def make_domain_for_space(space)
    domain = make_domain_for_org space.organization
    space.organization.add_domain(domain)
    domain
  end

  def make_manager_for_org(org)
    user = make_user_for_org(org)
    org.add_manager(user)
    user
  end

  def make_billing_manager_for_org(org)
    user = make_user_for_org(org)
    org.add_billing_manager(user)
    user
  end

  def make_auditor_for_org(org)
    user = make_user_for_org(org)
    org.add_auditor(user)
    user
  end

  def make_app_for_service_instance(service_instance)
    VCAP::CloudController::AppFactory.make(:space => service_instance.space)
  end

  def make_service_binding_for_service_instance(service_instance)
    app = VCAP::CloudController::AppFactory.make(:space => service_instance.space)
    app.space = service_instance.space
    VCAP::CloudController::ServiceBinding.make(
      :app => app,
      :service_instance => service_instance,
      :credentials => Sham.service_credentials
    )
  end

  def make_space_for_user(user)
    space = VCAP::CloudController::Space.make
    space.organization.add_user(user)
    space.add_developer(user)
    space
  end

  def make_user_with_default_space(opts = {})
    user = VCAP::CloudController::User.make(:admin => opts.has_key?(:admin), :active => true)
    space = make_space_for_user(user)
    user.default_space = space
    user
  end

  def make_user(opts = {})
    VCAP::CloudController::User.make(:admin => opts.has_key?(:admin), :active => true)
  end
end

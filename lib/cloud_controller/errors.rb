# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Errors
  include VCAP::RestAPI::Errors

  # TODO: normalize the error codes
  # make all the Takens be "UniqueViolation", make all the
  # invalids be the same lower digit, etc.
  #
  # While most of the code base tries to wrap at 80 columns, this file is an
  # exception.  This is far more readable when all on a single line.
  [
    # TODO: redo ranges.  10000 is for vcap base.
    # 20000 should be for cc base.
    ["QuotaDeclined",         HTTP::BAD_REQUEST, 200001, "Quota declined: %s"],
    ["MessageParseError",     HTTP::BAD_REQUEST, 200002, "Request invalid due to parse error: %s"],

    ["UserInvalid",           HTTP::BAD_REQUEST, 20001, "The user info is invalid: %s"],
    ["UaaIdTaken",            HTTP::BAD_REQUEST, 20002, "The UAA ID is taken: %s"],
    ["UserNotFound",          HTTP::BAD_REQUEST, 20003, "The user could not be found: %s"],

    ["OrganizationInvalid",   HTTP::BAD_REQUEST, 30001, "The organization info is invalid: %s"],
    ["OrganizationNameTaken", HTTP::BAD_REQUEST, 30002, "The organization name is taken: %s"],
    ["OrganizationNotFound",  HTTP::BAD_REQUEST, 30003, "The organization could not be found: %s"],

    ["SpaceInvalid",       HTTP::BAD_REQUEST, 40001, "The app space info is invalid: %s"],
    ["SpaceNameTaken",     HTTP::BAD_REQUEST, 40002, "The app space name is taken: %s"],
    ["SpaceUserNotInOrg",  HTTP::BAD_REQUEST, 40003, "The app space and the user are not in the same org: %s"],
    ["SpaceNotFound",      HTTP::BAD_REQUEST, 40004, "The app space could not be found: %s"],

    ["ServiceAuthTokenInvalid",    HTTP::BAD_REQUEST, 50001, "The service auth token is invalid: %s"],
    ["ServiceAuthTokenLabelTaken", HTTP::BAD_REQUEST, 50002, "The service auth token label is taken: %s"],
    ["ServiceAuthTokenNotFound",   HTTP::BAD_REQUEST, 50003, "The service auth token could not be found: %s"],

    ["ServiceInstanceNameInvalid", HTTP::BAD_REQUEST, 60001, "The service instance name is taken: %s"],
    ["ServiceInstanceNameTaken",   HTTP::BAD_REQUEST, 60002, "The service instance name is taken: %s"],
    ["ServiceInstanceServiceBindingWrongSpace", HTTP::BAD_REQUEST, 60003, "The service instance and the service binding are in different app spaces: %s"],
    ["ServiceInstanceInvalid",     HTTP::BAD_REQUEST, 60003, "The service instance is invalid: %s"],
    ["ServiceInstanceNotFound",    HTTP::BAD_REQUEST, 60004, "The service instance can not be found: %s"],

    ["RuntimeInvalid",   HTTP::BAD_REQUEST, 70001, "The runtime is invalid: %s"],
    ["RuntimeNameTaken", HTTP::BAD_REQUEST, 70002, "The runtime name is taken: %s"],
    ["RuntimeNotFound",  HTTP::BAD_REQUEST, 80003, "The runtime can not be found: %s"],

    ["FrameworkInvalid",   HTTP::BAD_REQUEST, 80001, "The framework is invalid: %s"],
    ["FrameworkNameTaken", HTTP::BAD_REQUEST, 80002, "The framework name is taken: %s"],
    ["FrameworkNotFound",  HTTP::BAD_REQUEST, 80003, "The framework can not be found: %s"],

    ["ServiceBindingInvalid",            HTTP::BAD_REQUEST, 90001, "The service binding is invalid: %s"],
    ["ServiceBindingDifferentSpaces", HTTP::BAD_REQUEST, 90002, "The app and the service are not in the same app space: %s"],
    ["ServiceBindingAppServiceTaken",    HTTP::BAD_REQUEST, 90003, "The app space binding to service is taken: %s"],
    ["ServiceBindingNotFound",           HTTP::BAD_REQUEST, 90004, "The service binding can not be found: %s"],

    ["AppInvalid",   HTTP::BAD_REQUEST, 100001, "The app is invalid: %s"],
    ["AppNameTaken", HTTP::BAD_REQUEST, 100002, "The app name is taken: %s"],
    ["AppNotFound",  HTTP::BAD_REQUEST, 100004, "The app name could not be found: %s"],

    ["ServicePlanInvalid",   HTTP::BAD_REQUEST, 110001, "The service plan is invalid: %s"],
    ["ServicePlanNameTaken", HTTP::BAD_REQUEST, 110002, "The service plan name is taken: %s"],
    ["ServicePlanNotFound",  HTTP::BAD_REQUEST, 110003, "The service plan could not be found: %s"],

    ["ServiceInvalid",    HTTP::BAD_REQUEST, 120001, "The service invalid: %s"],
    ["ServiceLabelTaken", HTTP::BAD_REQUEST, 120002, "The service lable is taken: %s"],
    ["ServiceNotFound",   HTTP::BAD_REQUEST, 120003, "The service could not be found: %s"],

    ["DomainInvalid",  HTTP::BAD_REQUEST, 130001, "The domain is invalid: %s"],
    ["DomainNotFound", HTTP::BAD_REQUEST, 130002, "The domain could not be found: %s"],

    ["LegacyApiWithoutDefaultSpace", HTTP::BAD_REQUEST, 140001, "A legacy api call requring a default app space was called, but no default app space is set for the user."],

    ["AppPackageInvalid", HTTP::BAD_REQUEST, 150001, "The app package is invalid: %s"],

    ["AppBitsUploadInvalid", HTTP::BAD_REQUEST, 160001, "The app upload is invalid: %s"]
  ].each do |e|
    define_error *e
  end
end

# Copyright (c) 2009-2012 VMware, Inc.
require "vcap/rest_api/http_constants"

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

    ["InvalidAuthToken", HTTP::UNAUTHORIZED, 100, "Invalid Auth Token"],

    ["QuotaDeclined",         HTTP::BAD_REQUEST, 1000, "Quota declined: %s"],
    ["MessageParseError",     HTTP::BAD_REQUEST, 1001, "Request invalid due to parse error: %s"],
    ["InvalidRelation",       HTTP::BAD_REQUEST, 1002, "Invalid relation: %s"],

    ["UserInvalid",           HTTP::BAD_REQUEST, 20001, "The user info is invalid: %s"],
    ["UaaIdTaken",            HTTP::BAD_REQUEST, 20002, "The UAA ID is taken: %s"],
    ["UserNotFound",          HTTP::NOT_FOUND,   20003, "The user could not be found: %s"],

    ["OrganizationInvalid",   HTTP::BAD_REQUEST, 30001, "The organization info is invalid: %s"],
    ["OrganizationNameTaken", HTTP::BAD_REQUEST, 30002, "The organization name is taken: %s"],
    ["OrganizationNotFound",  HTTP::NOT_FOUND,   30003, "The organization could not be found: %s"],

    ["SpaceInvalid",       HTTP::BAD_REQUEST, 40001, "The app space info is invalid: %s"],
    ["SpaceNameTaken",     HTTP::BAD_REQUEST, 40002, "The app space name is taken: %s"],
    ["SpaceUserNotInOrg",  HTTP::BAD_REQUEST, 40003, "The app space and the user are not in the same org: %s"],
    ["SpaceNotFound",      HTTP::NOT_FOUND,   40004, "The app space could not be found: %s"],

    ["ServiceAuthTokenInvalid",    HTTP::BAD_REQUEST, 50001, "The service auth token is invalid: %s"],
    ["ServiceAuthTokenLabelTaken", HTTP::BAD_REQUEST, 50002, "The service auth token label is taken: %s"],
    ["ServiceAuthTokenNotFound",   HTTP::NOT_FOUND,   50003, "The service auth token could not be found: %s"],

    ["ServiceInstanceNameInvalid", HTTP::BAD_REQUEST, 60001, "The service instance name is taken: %s"],
    ["ServiceInstanceNameTaken",   HTTP::BAD_REQUEST, 60002, "The service instance name is taken: %s"],
    ["ServiceInstanceServiceBindingWrongSpace", HTTP::BAD_REQUEST, 60003, "The service instance and the service binding are in different app spaces: %s"],
    ["ServiceInstanceInvalid",     HTTP::BAD_REQUEST, 60003, "The service instance is invalid: %s"],
    ["ServiceInstanceNotFound",    HTTP::NOT_FOUND, 60004, "The service instance could not be found: %s"],
    ["ServiceInstanceFreeQuotaExceeded",    HTTP::BAD_REQUEST, 60005, "You have exceeded your organization's services limit. Please login to your account and upgrade."],
    ["ServiceInstancePaidQuotaExceeded",    HTTP::BAD_REQUEST, 60006, "You have exceeded your organization's services limit. Please file a support ticket to request additional resources."],
    ["ServiceInstanceServicePlanNotAllowed",    HTTP::BAD_REQUEST, 60007, "The service instance cannot be created because paid service plans are not allowed."],

    ["RuntimeInvalid",   HTTP::BAD_REQUEST, 70001, "The runtime is invalid: %s"],
    ["RuntimeNameTaken", HTTP::BAD_REQUEST, 70002, "The runtime name is taken: %s"],
    ["RuntimeNotFound",  HTTP::NOT_FOUND,   70003, "The runtime could not be found: %s"],

    ["FrameworkInvalid",   HTTP::BAD_REQUEST, 80001, "The framework is invalid: %s"],
    ["FrameworkNameTaken", HTTP::BAD_REQUEST, 80002, "The framework name is taken: %s"],
    ["FrameworkNotFound",  HTTP::NOT_FOUND,   80003, "The framework could not be found: %s"],

    ["ServiceBindingInvalid",            HTTP::BAD_REQUEST, 90001, "The service binding is invalid: %s"],
    ["ServiceBindingDifferentSpaces",    HTTP::BAD_REQUEST, 90002, "The app and the service are not in the same app space: %s"],
    ["ServiceBindingAppServiceTaken",    HTTP::BAD_REQUEST, 90003, "The app space binding to service is taken: %s"],
    ["ServiceBindingNotFound",           HTTP::NOT_FOUND,   90004, "The service binding could not be found: %s"],

    ["AppInvalid",   HTTP::BAD_REQUEST, 100001, "The app is invalid: %s"],
    ["AppNameTaken", HTTP::BAD_REQUEST, 100002, "The app name is taken: %s"],
    ["AppNotFound",  HTTP::NOT_FOUND,   100004, "The app name could not be found: %s"],
    ["AppMemoryFreeQuotaExceeded",  HTTP::BAD_REQUEST,   100005, "You have exceeded your organization's memory limit. Please login to your account and upgrade."],
    ["AppMemoryPaidQuotaExceeded",  HTTP::BAD_REQUEST,   100006, "You have exceeded your organization's memory limit. Please file a support ticket to request additional resources."],

    ["ServicePlanInvalid",   HTTP::BAD_REQUEST, 110001, "The service plan is invalid: %s"],
    ["ServicePlanNameTaken", HTTP::BAD_REQUEST, 110002, "The service plan name is taken: %s"],
    ["ServicePlanNotFound",  HTTP::NOT_FOUND,   110003, "The service plan could not be found: %s"],

    ["ServiceInvalid",    HTTP::BAD_REQUEST, 120001, "The service is invalid: %s"],
    ["ServiceLabelTaken", HTTP::BAD_REQUEST, 120002, "The service lable is taken: %s"],
    ["ServiceNotFound",   HTTP::NOT_FOUND,   120003, "The service could not be found: %s"],

    ["DomainInvalid",   HTTP::BAD_REQUEST, 130001, "The domain is invalid: %s"],
    ["DomainNotFound",  HTTP::NOT_FOUND,   130002, "The domain could not be found: %s"],
    ["DomainNameTaken", HTTP::BAD_REQUEST, 130003, "The domain name is taken: %s"],

    ["LegacyApiWithoutDefaultSpace", HTTP::BAD_REQUEST, 140001, "A legacy api call requring a default app space was called, but no default app space is set for the user."],

    ["AppPackageInvalid", HTTP::BAD_REQUEST, 150001, "The app package is invalid: %s"],
    ["AppPackageNotFound", HTTP::NOT_FOUND, 150002, "The app package could not be found: %s"],

    ["AppBitsUploadInvalid", HTTP::BAD_REQUEST, 160001, "The app upload is invalid: %s"],

    ["StagingError", HTTP::BAD_REQUEST, 170001, "Staging error: %s"],

    ["SnapshotNotFound", HTTP::NOT_FOUND, 180001, "Snapshot could not be found: %s"],
    ["ServiceGatewayError", HTTP::SERVICE_UNAVAILABLE, 180002, "Service gateway internal error: %s"],
    ["ServiceNotImplemented", HTTP::NOT_IMPLEMENTED, 180003, "Operation not supported for service"],
    ["SDSNotAvailable", HTTP::NOT_IMPLEMENTED, 180004, "No serialization service backends available"],

    ["FileError",  HTTP::BAD_REQUEST, 190001, "File error: %s"],

    ["StatsError", HTTP::BAD_REQUEST, 200001, "Stats error: %s"],

    ["RouteInvalid",  HTTP::BAD_REQUEST, 210001, "The route is invalid: %s"],
    ["RouteNotFound", HTTP::NOT_FOUND, 210002, "The route could not be found: %s"],
    ["RouteHostTaken", HTTP::BAD_REQUEST, 210003, "The host is taken: %s"],

    ["InstancesError", HTTP::BAD_REQUEST, 220001, "Instances error: %s"],

    ["BillingEventQueryInvalid", HTTP::BAD_REQUEST, 230001, "Billing event query start_date and/or end_date are missing or invalid"],

    ["QuotaDefinitionNotFound", HTTP::NOT_FOUND, 240001, "Quota Definition could not be found: %s"],
    ["QuotaDefinitionNameTaken", HTTP::BAD_REQUEST, 240002, "Quota Definition is taken: %s"],
    ["QuotaDefinitionInvalid", HTTP::BAD_REQUEST, 240003, "Quota Definition is invalid: %s"],

  ].each do |e|
    define_error *e
  end
end

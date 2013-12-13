def org_with_paid_quota(authed_headers)
  quota = make_get_request(
    "/v2/quota_definitions?q=name%3Apaid",
    authed_headers
  )

  paid_quota_guid = quota.json_body["resources"][0]["metadata"]["guid"]

  make_post_request(
    "/v2/organizations",
    {
      "name" => "foo_org-#{SecureRandom.uuid}",
      "quota_definition_guid" => paid_quota_guid,
      "billing_enabled" => true
    }.to_json,
    authed_headers
  )
end

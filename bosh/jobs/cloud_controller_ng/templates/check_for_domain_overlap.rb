#!/usr/bin/env ruby

require '/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/lib/cloud_controller/domain_helper.rb'

system_domain = ARGV[0].downcase
app_domains   = ARGV[1].split(',').map(&:downcase)

is_sub_domain = CloudController::DomainHelper.is_sub_domain?(domain: system_domain, test_domains: app_domains)

if is_sub_domain
  puts "Invalid configuration: app_domains (#{app_domains}) contains a sub-domain of the system_domain: #{system_domain}."
  exit 1
end

exit 0

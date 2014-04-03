module VCAP::Services::ServiceBrokers
  class ValidationErrorsFormatter
    INDENT = '  '.freeze
    def format(validation_errors)
      message = "\n"
      validation_errors.messages.each { |e| message += "#{e}\n" }
      validation_errors.nested_errors.each do |service, service_errors|
        next if service_errors.empty?

        message += "Service #{service.name}\n"
        service_errors.messages.each do |error|
          message += "#{INDENT}#{error}\n"
        end

        service_errors.nested_errors.each do |plan, plan_errors|
          next if plan_errors.empty?

          message += "#{INDENT}Plan #{plan.name}\n"
          plan_errors.messages.each do |error|
            message += "#{INDENT}#{INDENT}#{error}\n"
          end
        end
      end
      message
    end
  end
end

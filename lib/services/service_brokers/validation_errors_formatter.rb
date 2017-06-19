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
          message += indent + "#{error}\n"
        end

        service_errors.nested_errors.each do |plan, plan_errors|
          next if plan_errors.empty?

          message += indent + "Plan #{plan.name}\n"
          plan_errors.messages.each do |error|
            message += indent(2) + "#{error}\n"
          end

          plan_errors.nested_errors.each do |schema, schema_errors|
            message += indent(2) + "Schemas\n"
            schema_errors.messages.each do |error|
              message += indent(3) + "#{error}\n"
            end
          end
        end
      end
      message
    end

    def indent(num=1)
      INDENT.to_s * num
    end
  end
end

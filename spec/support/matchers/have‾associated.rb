RSpec::Matchers.define :have_associated do |association, options={}|
  description do
    "have associated #{association}"
  end
  match do |_|
    instance = options[:test_instance]
    instance ||= described_class.make
    associated_instance = get_associated_instance(instance, association, options)

    if association[-1] == 's'
      instance.send("add_#{association.to_s.singularize}", associated_instance)
      instance.send(association).include? associated_instance.reload
    else
      instance.send("#{association}=", associated_instance)
      instance.send(association) == associated_instance.reload
    end
  end

  def get_associated_instance(instance, association, options)
    if options[:associated_instance]
      options[:associated_instance].call(instance)
    else
      associated_class = options[:class] || "VCAP::CloudController::#{association.to_s.classify}".constantize
      associated_class.make
    end
  end
end

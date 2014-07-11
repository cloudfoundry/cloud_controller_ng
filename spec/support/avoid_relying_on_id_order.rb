# Ensures that entries are not returned ordered by the id field by
# default. Breaks the tests (deliberately) unless we order by id
# explicitly. In postgres the order is random unless specified.
class VCAP::CloudController::App
  set_dataset dataset.order(:guid)
end

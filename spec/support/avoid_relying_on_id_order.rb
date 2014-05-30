# Ensures that entries are not returned ordered by the id field by
# default. Breaks the tests (deliberately) unless we order by id
# explicitly. In sqlite, the default ordering, although not guaranteed,
# is de facto by id. In postgres the order is random unless specified.
class VCAP::CloudController::App
  set_dataset dataset.order(:guid)
end

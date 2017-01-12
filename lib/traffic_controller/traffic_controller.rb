$LOAD_PATH.unshift(File.expand_path('../models', __FILE__))

require 'traffic_controller/models/envelope.pb'
require 'traffic_controller/models/error.pb'
require 'traffic_controller/models/http.pb'
require 'traffic_controller/models/log.pb'
require 'traffic_controller/models/metric.pb'
require 'traffic_controller/models/uuid.pb'

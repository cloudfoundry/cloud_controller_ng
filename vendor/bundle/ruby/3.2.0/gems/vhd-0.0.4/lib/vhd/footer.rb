class Vhd::Footer < BitStruct
  unsigned :cookie        , 8   , "Cookie"
  unsigned :features      , 4   , "Features"
  unsigned :ff            , 4   , "File Format"
  unsigned :data_offset   , 8   , "Data Offset"
  unsigned :timestamp     , 4   , "Timestamp"
  unsigned :creator_app   , 4   , "Creator Application"
  unsigned :creator_ver   , 4   , "Creator Version"
  unsigned :creator_host  , 4   , "Creator Host OS"
  unsigned :original_size , 8   , "Original Size"
  unsigned :current_size  , 8   , "Current Size"
  unsigned :geometry      , 4   , "Disk Geometry"
  unsigned :type          , 4   , "Disk Type"
  unsigned :checksum      , 4   , "Footer Checksum"
  unsigned :uuid          , 16  , "Unique Id"
  unsigned :saved_state   , 1   , "Saved State"
  unsigned :reserved      , 427 , "Reserved Space"

  initial_value.cookie       = "conectix"
  initial_value.features     = 2
  initial_value.ff           = 65536
  initial_value.offset       = 18446744073709551615
  initial_value.timestamp    = (Time.now - Time.parse("Jan 1, 2000 12:00:00 AM GMT")).to_i
  initial_value.creator_app  = "rvhd"
  initial_value.creator_ver  = 0
  initial_value.creator_host = "Wi2k"
  initial_value.type         = 2
  initial_value.uuid         = SecureRandom.uuid.delete('-')
  initial_value.saved_state  = 0
  initial_value.reserved     = 0
end

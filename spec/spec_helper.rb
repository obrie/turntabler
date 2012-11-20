$LOAD_PATH << File.expand_path("../../lib", __FILE__)

require 'turntabler'

RSpec.configure do |config|
  config.order = 'random'
end

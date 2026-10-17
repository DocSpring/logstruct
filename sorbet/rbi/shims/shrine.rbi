# typed: true

# Shrine loads its plugins on demand, so Tapioca doesn't generate RBIs for them
module Shrine::Plugins::Instrumentation
  class LogSubscriber
    def self.call(event); end
  end
end

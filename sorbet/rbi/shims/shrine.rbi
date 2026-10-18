# typed: true

# Shrine loads its plugins on demand, so Tapioca doesn't generate RBIs for them
module Shrine::Plugins::Instrumentation
  class LogSubscriber
    def self.call(event); end
  end
end

class Shrine
  # Added by the instrumentation plugin, which Shrine loads on demand
  sig { params(event_name: Symbol, subscriber: T.proc.params(event: T.untyped).void).void }
  def self.subscribe(event_name, &subscriber); end
end

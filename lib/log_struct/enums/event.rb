# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log event types as an enum
  class Event < T::Enum
    enums do
      # Plain log messages
      Log = new(:log)

      # Request events
      Request = new(:request)

      # Job events
      Enqueue = new(:enqueue)
      Schedule = new(:schedule)
      Start = new(:start)
      Finish = new(:finish)

      # File storage events (ActiveStorage, Shrine, CarrierWave, etc.)
      Upload = new(:upload)
      Download = new(:download)
      Delete = new(:delete)
      Metadata = new(:metadata)
      Exist = new(:exist)
      Stream = new(:stream)
      Url = new(:url)

      # Data generation events
      Generate = new(:generate)

      # Email events
      Delivery = new(:delivery)
      Delivered = new(:delivered)

      # Configuration / boot events
      Load = new(:load)
      Update = new(:update)
      Save = new(:save)
      Restore = new(:restore)

      # Security events
      IPSpoof = new(:ip_spoof)
      CSRFViolation = new(:csrf_violation)
      BlockedHost = new(:blocked_host)

      # Database events
      Database = new(:database)

      # Error events
      Error = new(:error)

      # Fallback
      Unknown = new(:unknown)
    end
  end
end

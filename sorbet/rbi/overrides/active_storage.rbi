# typed: strong

# The issue arises because ActiveStorage::Attached::One itself doesn't
# directly implement download; the method is provided dynamically at
# runtime by Rails' Active Storage attachment classes. To resolve this,
# you need to explicitly define the download method in your RBI file for
# ActiveStorage::Attached::One.

# Create or update an RBI file (e.g., sorbet/rbi/shims/active_storage.rbi) as follows:

module ActiveStorage
  class Attached::One
    sig { returns(String) }
    def download; end

    sig { returns(String) }
    def key; end
  end

  class Blob < ActiveStorage::Record
    sig { returns(String) }
    def key; end

    sig { returns(String) }
    def filename; end

    sig { params(content_type: String).returns(T::Boolean) }
    def content_type?(content_type); end

    sig { returns(Integer) }
    def byte_size; end

    sig { returns(String) }
    def checksum; end

    sig { returns(String) }
    def service_name; end

    sig { returns(ActiveStorage::Service) }
    def self.service; end
  end
end

# typed: true

class Sorbet
  module Typescript
    class Exporter
      def initialize(enum_namespaces: T.untyped, struct_namespaces: T.untyped); end
      def export(enums_json: T.untyped = nil, structs_json: T.untyped = nil, typescript_file: T.untyped = nil, property_map_json: T.untyped = nil); end
    end
  end
end

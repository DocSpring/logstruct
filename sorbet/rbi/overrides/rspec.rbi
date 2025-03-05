# typed: strong

module RSpec::Mocks::ExampleMethods::ExpectHost
  # Method definition from rspec-expectations. Has an optional argument and supports a block.
  sig { params(value: T.untyped, block: T.untyped).returns(T.untyped) }
  def expect(value = T.untyped, &block); end
end

# typed: strict

# From https://github.com/FooBarWidget/rspec-sorbet-types
# Workaround for https://github.com/sorbet/sorbet/issues/8143
if false # rubocop:disable Lint/LiteralAsCondition
  T::Sig::WithoutRuntime.sig { params(block: T.proc.bind(T::Private::Methods::DeclBuilder).void).void }
  def sig(&block)
  end

  T::Sig::WithoutRuntime.sig { params(block: T.proc.bind(T::Private::Methods::DeclBuilder).void).void }
  def rsig(&block)
  end
end

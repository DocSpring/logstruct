# typed: strong

class Document
  sig { returns(ActiveStorage::Attached::One) }
  def file; end
end

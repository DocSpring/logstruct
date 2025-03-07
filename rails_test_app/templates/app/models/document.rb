# typed: strict
# frozen_string_literal: true

class Document < ApplicationRecord
  extend T::Sig

  has_one_attached :file

  sig { params(filename: String, content: String).returns(Document) }
  def self.create_with_file(filename:, content:)
    document = create!
    document.file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: "text/plain"
    )
    document
  end
end

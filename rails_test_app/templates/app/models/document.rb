# typed: strict
# frozen_string_literal: true

class Document < ApplicationRecord
  extend T::Sig

  # ActiveStorage attachment (used by active_storage_test.rb)
  has_one_attached :active_storage_file

  # Shrine attachment (used by shrine_logging_test.rb)
  include DocumentUploader::Attachment(:file)

  sig { params(filename: String, content: String).returns(Document) }
  def self.create_with_file(filename:, content:)
    document = T.let(create!, Document)
    document.active_storage_file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: "text/plain"
    )
    document
  end

  sig { params(filename: String, content: String).returns(Document) }
  def self.create_with_shrine_file(filename:, content:)
    io = StringIO.new(content)
    io.define_singleton_method(:original_filename) { filename }
    document = T.let(new, Document)
    document.file = io
    document.save!
    document
  end
end

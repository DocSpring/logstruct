# typed: true
# frozen_string_literal: true

require "test_helper"
require "carrierwave"
require "tmpdir"

class CarrierWaveIntegrationTest < ActiveSupport::TestCase
  class FakeDownloader
    def initialize(_uploader)
    end

    def download(_url, _headers)
      CarrierWave::SanitizedFile.new(tempfile: StringIO.new("remote image"), filename: "remote.png", content_type: "image/png")
    end
  end

  class AvatarUploader < CarrierWave::Uploader::Base
    storage :file
    self.downloader = FakeDownloader
  end

  setup do
    @root = Dir.mktmpdir
    # On the uploader itself: CarrierWave copies a setting into a subclass the first time it's read
    AvatarUploader.root = @root
    LogStruct::Integrations::CarrierWave.setup(LogStruct.config)

    @upload = File.join(@root, "avatar.png")
    File.write(@upload, "png bytes")
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "storing a file logs an upload" do
    uploader = AvatarUploader.new
    uploader.store!(File.open(@upload))

    upload = logged_lines.find { |line| line["src"] == "carrierwave" }

    assert_equal ["upload", "avatar.png", "avatar.png", 9, "file"],
      upload&.values_at("evt", "file_id", "filename", "size", "storage")
    assert_kind_of Float, upload["duration_ms"]
  end

  test "saving a record calls store! on files that are already stored, which logs nothing" do
    AvatarUploader.new.store!(File.open(@upload))
    uploader = AvatarUploader.new
    uploader.retrieve_from_store!("avatar.png")

    assert_no_carrierwave_lines { uploader.store! }
  end

  test "loading a stored file logs nothing: it reads no data" do
    AvatarUploader.new.store!(File.open(@upload))

    assert_no_carrierwave_lines { AvatarUploader.new.retrieve_from_store!("avatar.png") }
  end

  test "removing a stored file logs a delete" do
    uploader = AvatarUploader.new
    uploader.store!(File.open(@upload))
    uploader.remove!

    delete = logged_lines.find { |line| line["src"] == "carrierwave" && line["evt"] == "delete" }

    assert_equal ["avatar.png", "file", "CarrierWaveIntegrationTest::AvatarUploader"], delete&.values_at("file_id", "storage", "uploader")
    refute_path_exists File.join(@root, "uploads", "avatar.png")
  end

  test "removing an uploader without a file logs nothing" do
    assert_no_carrierwave_lines { AvatarUploader.new.remove! }
  end

  test "downloading a remote file logs a download" do
    uploader = AvatarUploader.new
    uploader.download!("https://images.example.com/remote.png?token=secret")

    download = logged_lines.find { |line| line["src"] == "carrierwave" && line["evt"] == "download" }

    assert_equal ["remote.png", "remote.png", "image/png", 12], download&.values_at("file_id", "filename", "mime_type", "size")
    refute_includes download.to_s, "secret"
  end

  test "a problem building the line doesn't stop the upload" do
    LogStruct.config.local_environments = []
    uploader = AvatarUploader.new
    LogStruct::Log::CarrierWave::Upload.stub(:new, ->(**) { raise ArgumentError, "bad field" }) do
      uploader.store!(File.open(@upload))
    end

    assert_path_exists File.join(@root, "uploads", "avatar.png")
    error = logged_lines.find { |line| line["evt"] == "error" }

    assert_equal ["ArgumentError", "bad field"], error&.values_at("error_class", "msg")
  end

  private

  def logged_lines
    ::SemanticLogger.flush
    TEST_LOG_IO.string.lines.map { |line| JSON.parse(line) }
  end

  def assert_no_carrierwave_lines
    ::SemanticLogger.flush
    offset = TEST_LOG_IO.string.bytesize
    yield
    ::SemanticLogger.flush
    lines = TEST_LOG_IO.string.byteslice(offset..).to_s.lines.map { |line| JSON.parse(line) }

    assert_empty(lines.select { |line| line["src"] == "carrierwave" })
  end
end

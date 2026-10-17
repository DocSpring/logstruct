# typed: true
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ActiveStorageTest < ActiveSupport::TestCase
  setup do
    # Use StringIO to capture log output
    @log_output = StringIO.new
    @original_logger = Rails.logger

    # Create a new logger with our StringIO and LogStruct's formatter
    logger = Logger.new(@log_output)
    logger.formatter = LogStruct::Formatter.new
    Rails.logger = logger
  end

  teardown do
    # Restore the original logger
    Rails.logger = @original_logger
  end

  # Helper method to parse log entries
  def find_log_entries(event_type)
    # Reset the StringIO position to the beginning
    @log_output.rewind

    # Parse the log contents looking for JSON data
    logs = []
    @log_output.each_line do |line|
      # Log lines might have timestamps or other text before the JSON
      if line =~ /(\{.+\})/
        json = JSON.parse($1)
        # Only include active storage logs with the specified event
        logs << json if json["src"] == "storage" && json["evt"] == event_type
      end
    rescue JSON::ParserError
      # Skip lines that don't contain valid JSON
    end

    logs
  end

  test "logs are created when uploading a file" do
    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Create a document with an attached file, which should trigger upload
    Document.create_with_file(
      filename: "test_file.txt",
      content: "This is test content for Active Storage"
    )

    # Give some time for the async events to process
    sleep(0.2)

    # Find upload logs in the captured output
    upload_logs = find_log_entries("upload")

    assert_not_empty upload_logs, "Expected upload logs to be generated"

    upload_log = upload_logs.first

    assert_equal "storage", upload_log["src"]
    assert_equal "upload", upload_log["evt"]
    assert_equal "Disk", upload_log["storage"]
    assert_not_nil upload_log["file_id"]
    assert_not_nil upload_log["checksum"]
    assert_not_nil upload_log["duration_ms"]
  end

  test "logs are created when downloading a file" do
    # Create a document with a file for testing
    document = Document.create_with_file(
      filename: "download_test.txt",
      content: "This is content to download"
    )

    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Download the file
    document.active_storage_file.download

    # Give some time for the async events to process
    sleep(0.2)

    # Find download logs in the captured output
    download_logs = find_log_entries("download")

    assert_not_empty download_logs, "Expected download logs to be generated"

    download_log = download_logs.first

    assert_equal "storage", download_log["src"]
    assert_equal "download", download_log["evt"]
    assert_equal "Disk", download_log["storage"]
    assert_not_nil download_log["file_id"]
    assert_not_nil download_log["duration_ms"]
  end

  test "a streaming download is logged as a download" do
    document = Document.create_with_file(filename: "stream_test.txt", content: "Streamed content")
    @log_output.truncate(0)
    @log_output.rewind

    chunks = []
    document.active_storage_file.download { |chunk| chunks << chunk }

    assert_equal "Streamed content", chunks.join
    assert_not_empty find_log_entries("download"), "Expected a download line"
    assert_empty find_log_entries("metadata")
  end

  test "url and exist lines are debug lines, as Rails logs them" do
    document = Document.create_with_file(filename: "levels_test.txt", content: "Content")
    @log_output.truncate(0)
    @log_output.rewind

    ActiveStorage::Current.url_options = {host: "files.example.com"}
    document.active_storage_file.blob.url
    ActiveStorage::Blob.service.exist?(document.active_storage_file.key)

    assert_equal ["debug"], (find_log_entries("url") + find_log_entries("exist")).map { |line| line["lvl"] }.uniq
  ensure
    ActiveStorage::Current.url_options = nil
  end

  test "Rails' own ActiveStorage lines are replaced by LogStruct's" do
    rails_subscribers = ActiveSupport::LogSubscriber.log_subscribers.select do |subscriber|
      subscriber.is_a?(ActiveStorage::LogSubscriber)
    end

    assert_empty rails_subscribers
  end

  test "a problem building a line doesn't stop the upload in production" do
    saved = LogStruct.config.local_environments
    LogStruct.config.local_environments = []
    document = LogStruct::Log::ActiveStorage::Upload.stub(:new, ->(**) { raise ArgumentError, "bad field" }) do
      Document.create_with_file(filename: "failing_line.txt", content: "Content")
    end

    assert_equal "Content", document.active_storage_file.download
    errors = @log_output.string.lines.filter_map { |line| JSON.parse(line[/\{.+\}/]) if line.include?('"evt":"error"') }

    assert_equal [["ArgumentError", "bad field"]], errors.map { |line| line.values_at("error_class", "msg") }
  ensure
    LogStruct.config.local_environments = saved
  end

  test "logs are created when checking if a file exists" do
    # Create a document with a file for testing
    document = Document.create_with_file(
      filename: "exist_test.txt",
      content: "This is content to check existence"
    )

    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Check if file exists - we need to hit the storage service directly to trigger the exist event
    # In ActiveStorage, we need to directly check through the storage service
    storage = ActiveStorage::Blob.service
    storage.exist?(document.active_storage_file.key)

    # Give some time for the async events to process
    sleep(0.2)

    # Find existence check logs in the captured output
    exist_logs = find_log_entries("exist")

    assert_not_empty exist_logs, "Expected existence check logs to be generated"

    exist_log = exist_logs.first

    assert_equal "storage", exist_log["src"]
    assert_equal "exist", exist_log["evt"]
    assert_equal "Disk", exist_log["storage"]
    assert_not_nil exist_log["file_id"]
  end

  test "logs are created when deleting a file" do
    # Create a document with a file for testing
    document = Document.create_with_file(
      filename: "delete_test.txt",
      content: "This is content to delete"
    )

    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Delete the file
    document.active_storage_file.purge

    # Give some time for the async events to process
    sleep(0.2)

    # Find delete logs in the captured output
    delete_logs = find_log_entries("delete")

    assert_not_empty delete_logs, "Expected delete logs to be generated"

    delete_log = delete_logs.first

    assert_equal "storage", delete_log["src"]
    assert_equal "delete", delete_log["evt"]
    assert_equal "Disk", delete_log["storage"]
    assert_not_nil delete_log["file_id"]
  end

  # Purging an image deletes its variants too, by prefix
  test "deleting files by prefix logs a delete with the prefix" do
    @log_output.truncate(0)
    @log_output.rewind

    ActiveStorage::Blob.service.delete_prefixed("variants/abc123/")

    delete_log = find_log_entries("delete").first

    assert_equal ["Disk", "variants/abc123/"], delete_log&.values_at("storage", "prefix")
    assert_not delete_log&.key?("file_id")
  end

  test "url logs leave out the signed URL" do
    document = Document.create_with_file(filename: "url_test.txt", content: "Signed URL content")
    @log_output.truncate(0)
    @log_output.rewind

    ActiveStorage::Current.url_options = {host: "files.example.com"}
    url = document.active_storage_file.blob.url

    url_logs = find_log_entries("url")

    assert_not_empty url_logs, "Expected url logs to be generated"
    assert_equal document.active_storage_file.blob.key, url_logs.first["file_id"]
    refute url_logs.first.key?("url")
    @log_output.rewind
    log_text = @log_output.read

    assert_not_includes log_text, URI.parse(url).path
  ensure
    ActiveStorage::Current.url_options = nil
  end

  test "logs contain expected metadata fields" do
    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Create a document with specific metadata
    document = Document.create!

    # Clear the buffer again to make sure we only capture the attach operation
    @log_output.truncate(0)
    @log_output.rewind

    # Now attach the file with our known metadata
    document.active_storage_file.attach(
      io: StringIO.new("Test content with specific metadata"),
      filename: "metadata_test.txt",
      content_type: "text/plain"
    )

    # Give some time for the async events to process
    sleep(0.2)

    # Find upload logs in the captured output
    upload_logs = find_log_entries("upload")

    assert_not_empty upload_logs, "Expected upload logs to be generated"

    upload_log = upload_logs.first

    # Verify upload log contains the expected fields

    # The checksum should be present
    assert_not_nil upload_log["checksum"]

    # Check for duration which should always be present
    assert_not_nil upload_log["duration_ms"]
    # Rails' event has the blob's key, not its filename
    assert_empty upload_log.keys & %w[filename mime_type size metadata]
  end

  test "a metadata update logs the content type, not the disposition's filename" do
    @log_output.truncate(0)
    @log_output.rewind

    ActiveSupport::Notifications.instrument("service_update_metadata.active_storage",
      key: "m3k9x2q7",
      service: "S3",
      content_type: "application/pdf",
      disposition: 'inline; filename="Jane Doe lease.pdf"')
    ::SemanticLogger.flush

    line = find_log_entries("metadata").last

    assert_equal ["m3k9x2q7", "application/pdf"], line&.values_at("file_id", "mime_type")
    assert_not_includes @log_output.string, "Jane Doe"
  end
end

# typed: true
# frozen_string_literal: true

require "test_helper"

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
    document = Document.create_with_file(
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
    assert_not_nil upload_log["duration"]
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
    document.file.download

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
    assert_not_nil download_log["duration"]
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
    storage.exist?(document.file.key)

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
    document.file.purge

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
    document.file.attach(
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

    # Check file size if available - from the blob service
    if upload_log["size"]
      assert_kind_of Integer, upload_log["size"]
    end

    # Check for duration which should always be present
    assert_not_nil upload_log["duration"]
  end
end

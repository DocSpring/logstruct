# typed: true
# frozen_string_literal: true

require "shrine"
require "shrine/storage/memory"

# Use memory storage for tests (fast, no filesystem needed)
Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new
}

# Standard Shrine plugins matching DocSpring's production setup
Shrine.plugin :cached_attachment_data
Shrine.plugin :activerecord

# IMPORTANT: This is the key plugin that causes issues.
# A normal Rails app will have this configured BEFORE LogStruct loads.
# LogStruct must handle this gracefully and NOT add a duplicate log_subscriber.
Shrine.plugin :instrumentation

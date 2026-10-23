#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "fileutils"
require "sorbet-runtime"

module LogStruct
  module Codegen
    # The generators write into a staging directory that mirrors the repository, and their files move into the
    # repository once they're complete and formatted. Formatting takes seconds, and `task ci` stops the generator
    # when a step running beside it fails: files formatted where they were committed were left unformatted.
    class Staging
      extend T::Sig

      sig { returns(String) }
      attr_reader :dir

      sig { params(root: String, dir: String).void }
      def initialize(root, dir)
        @root = root
        @dir = dir
      end

      # The staged path of the file that will be at relative_path in the repository
      sig { params(relative_path: String).returns(String) }
      def path(relative_path)
        File.join(@dir, relative_path)
      end

      sig { params(relative_path: String, content: String).void }
      def write(relative_path, content)
        staged = path(relative_path)
        FileUtils.mkdir_p(File.dirname(staged))
        File.write(staged, content)
      end

      # Moves the staged files under relative_dir into the repository, each with one rename, so Sorbet, tsc or a
      # test reading them during generation gets the old file or the new one. With prune, files the generators
      # no longer write are deleted.
      sig { params(relative_dir: String, prune: T::Boolean).void }
      def install(relative_dir, prune: false)
        staged_dir = path(relative_dir)
        # Nothing was generated here, which prune would read as every file being removed
        return unless File.directory?(staged_dir)

        dest_dir = File.join(@root, relative_dir)
        installed = files_under(staged_dir)
        installed.each do |file|
          dest = File.join(dest_dir, file)
          FileUtils.mkdir_p(File.dirname(dest))
          File.rename(File.join(staged_dir, file), dest)
        end
        remove_other_files(dest_dir, installed.to_set) if prune
      end

      private

      sig { params(dir: String).returns(T::Array[String]) }
      def files_under(dir)
        Dir.glob("**/*", base: dir).select { |file| File.file?(File.join(dir, file)) }
      end

      sig { params(dir: String, kept: T::Set[String]).void }
      def remove_other_files(dir, kept)
        files_under(dir).each do |file|
          File.delete(File.join(dir, file)) unless kept.include?(file)
        end
        # A removed log source's directory, after the directories inside it
        Dir.glob("**/", base: dir).sort.reverse_each do |subdir|
          path = File.join(dir, subdir)
          Dir.rmdir(path) if Dir.empty?(path)
        end
      end
    end
  end
end

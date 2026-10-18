# typed: true
# frozen_string_literal: true

require "test_helper"
require "yaml"

module LogStruct
  # The Release workflow publishes the gem and the Terraform provider. A tag that doesn't match
  # lib/log_struct/version.rb must stop both, so the tag check is in the job every other job needs.
  class ReleaseWorkflowTest < ActiveSupport::TestCase
    WORKFLOW = File.expand_path("../../.github/workflows/release.yml", __dir__)

    def jobs
      @jobs ||= YAML.safe_load_file(WORKFLOW).fetch("jobs")
    end

    def needs(job_id)
      Array(jobs.fetch(job_id)["needs"])
    end

    def all_needs(job_id)
      needs(job_id).flat_map { |need| [need, *all_needs(need)] }.uniq
    end

    test "the first job validates the tag against version.rb" do
      steps = jobs.fetch("wait_ci").fetch("steps").map { |step| step["run"].to_s }

      assert(steps.any? { |run| run.include?("lib/log_struct/version.rb") && run.include?("does not match") })
      assert_empty needs("wait_ci")
    end

    test "every other job needs the job that validates the tag" do
      jobs.each_key do |job_id|
        next if job_id == "wait_ci"

        assert_includes all_needs(job_id), "wait_ci", job_id
      end
    end

    test "only the publishing jobs run in the release environment" do
      environments = jobs.to_h { |job_id, job| [job_id, job["environment"]] }.compact

      assert_equal({"publish_gem" => "release", "publish_provider" => "release"}, environments)
    end
  end
end

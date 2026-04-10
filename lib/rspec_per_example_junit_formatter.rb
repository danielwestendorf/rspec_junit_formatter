# frozen_string_literal: true

require "rspec_junit_formatter"

# A JUnit XML formatter that reports the file path and line number of each
# individual example rather than the top-level example group file path.
#
# Usage:
#   rspec --format RSpecPerExampleJUnitFormatter --out rspec.xml
class RSpecPerExampleJUnitFormatter < RSpecJUnitFormatter
  RSpec::Core::Formatters.register self,
    :start,
    :stop,
    :dump_summary

private

  def example_group_file_path_for(notification)
    notification.example.id
  end
end

RspecPerExampleJunitFormatter = RSpecPerExampleJUnitFormatter

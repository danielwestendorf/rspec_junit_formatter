require "pty"
require "stringio"
require "nokogiri"
require "rspec_per_example_junit_formatter"

describe RspecPerExampleJunitFormatter do
  TMP_DIR = File.expand_path("../../tmp", __FILE__) unless defined?(TMP_DIR)
  EXAMPLE_DIR = File.expand_path("../../example", __FILE__) unless defined?(EXAMPLE_DIR)

  before(:all) { ENV.delete("TEST_ENV_NUMBER") }

  let(:formatter_output_path) { File.join(TMP_DIR, "per_example_junit.xml") }
  let(:formatter_output) { output; File.read(formatter_output_path) }

  let(:formatter_arguments) { ["--format", "RspecPerExampleJunitFormatter", "--out", formatter_output_path] }
  let(:extra_arguments) { [] }

  let(:color_opt) do
    RSpec.configuration.respond_to?(:color_mode=) ? "--force-color" : "--color"
  end

  def safe_pty(command, **pty_options)
    output = StringIO.new

    PTY.spawn(*command, **pty_options) do |r, w, pid|
      begin
        r.each_line { |line| output.puts(line) }
      rescue Errno::EIO
      ensure
        Process.wait pid
      end
    end

    output.string
  end

  def execute_example_spec
    command = ["bundle", "exec", "rspec", *formatter_arguments, color_opt, *extra_arguments]

    safe_pty(command, chdir: EXAMPLE_DIR)
  end

  let(:output) { execute_example_spec }

  let(:doc) { Nokogiri::XML::Document.parse(formatter_output) }

  let(:testsuite) { doc.xpath("/testsuite").first }
  let(:testcases) { doc.xpath("/testsuite/testcase") }
  let(:successful_testcases) { doc.xpath("/testsuite/testcase[not(failure) and not(skipped)]") }
  let(:pending_testcases) { doc.xpath("/testsuite/testcase[skipped]") }
  let(:failed_testcases) { doc.xpath("/testsuite/testcase[failure]") }
  let(:shared_testcases) { doc.xpath("/testsuite/testcase[contains(@name, 'shared example')]") }

  # Combined into a single example so we don't have to re-run the example rspec
  # process over and over.
  it "correctly describes the test results with per-example scoped IDs", aggregate_failures: true do
    # file attributes use the example.id format with scoped IDs

    testcases.each do |testcase|
      expect(testcase["file"]).to match(%r{\./spec/\w+\.rb\[\d+(?::\d+)*\]}),
        "expected file attribute '#{testcase["file"]}' to use scoped ID format"
    end

    # different examples have different scoped IDs

    file_attrs = testcases.map { |tc| tc["file"] }
    expect(file_attrs.uniq.size).to eql(testcases.size)

    # shared examples are scoped under the including file, not the definition file

    shared_testcases.each do |testcase|
      expect(testcase["file"]).to match(%r{example_spec\.rb\[})
    end

    # classname is derived from file path without scoped ID leaking in

    testcases.each do |testcase|
      expect(testcase["classname"]).to eql("spec.example_spec")
      expect(testcase["classname"]).not_to match(/\[/)
    end

    # testsuite attributes are correct

    expect(testsuite).not_to be(nil)
    expect(testsuite["tests"]).to eql("12")
    expect(testsuite["skipped"]).to eql("1")
    expect(testsuite["failures"]).to eql("8")
    expect(testsuite["errors"]).to eql("0")
  end
end

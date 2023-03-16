# typed: true
# frozen_string_literal: true

require "test_helper"
require "expectations/expectations_test_runner"

class SemanticHighlightingExpectationsTest < ExpectationsTestRunner
  expectations_tests RubyLsp::Requests::SemanticHighlighting, "semantic_highlighting"

  def run_expectations(source)
    document = RubyLsp::Document.new(source, 1, "file:///fake.rb")
    range = @__params&.any? ? @__params.first : nil

    if range
      start_line = range.dig(:start, :line)
      end_line = range.dig(:end, :line)
      processed_range = start_line..end_line
    end

    RubyLsp::Requests::SemanticHighlighting.new(
      document,
      range: processed_range,
      encoder: RubyLsp::Requests::Support::SemanticTokenEncoder.new,
    ).run
  end

  def assert_expectations(source, expected)
    actual = run_expectations(source).data
    assert_equal(json_expectations(expected).to_json, decode_tokens(actual).to_json)
  end

  private

  def decode_tokens(array)
    tokens = []
    array.each_slice(5) do |token|
      tokens << {
        delta_line: token[0],
        delta_start_char: token[1],
        length: token[2],
        token_type: token[3],
        token_modifiers: token[4],
      }
    end
    tokens
  end
end

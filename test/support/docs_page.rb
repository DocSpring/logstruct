# typed: true
# frozen_string_literal: true

# For tests that check the example lines on a docs page against what LogStruct writes
module DocsPage
  extend T::Helpers

  requires_ancestor { Minitest::Assertions }

  def docs_page(path)
    (@docs_pages ||= {})[path] ||= File.read(path)
  end

  # A template literal on the page: const NAME = `...`;
  def docs_page_json(path, name)
    source = docs_page(path)[/const #{name} = `(.*?)`;/m, 1]

    assert source, "#{name} not found in #{path}"
    JSON.parse(T.must(source))
  end
end

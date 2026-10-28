require "test_helper"
require "tmpdir"

# This gem brings roo/roo-xls to every Thecore app; the spot items importer reads its files with
# exactly `Roo::Spreadsheet.open(file).sheet(0).parse(headers: true, clean: true)`. roo 3 moved to
# rubyzip 3 (rubyzip 2.x has a path traversal, CVE-2026-85396), so this guards that both the
# .xlsx (rubyzip) and the .xls (roo-xls/spreadsheet) paths still read a sheet the same way.
#
# With `headers: true` roo returns the header row itself as the first hash, on roo 2 and 3 alike.
class SpreadsheetImportTest < ActiveSupport::TestCase
  EXPECTED = [
    { "code" => "code", "name" => "name" },
    { "code" => "A1", "name" => "Bolt" },
    { "code" => "B2", "name" => "Nut" }
  ].freeze

  test "reads an .xlsx sheet with headers" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "items.xlsx")
      write_xlsx(path, [%w[code name], %w[A1 Bolt], %w[B2 Nut]])
      assert_equal EXPECTED, parse(path)
    end
  end

  test "reads an .xls sheet with headers" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "items.xls")
      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet
      [%w[code name], %w[A1 Bolt], %w[B2 Nut]].each_with_index { |row, i| sheet.row(i).concat(row) }
      book.write(path)
      assert_equal EXPECTED, parse(path)
    end
  end

  private

  def parse(path)
    Roo::Spreadsheet.open(path).sheet(0).parse(headers: true, clean: true)
  end

  # Smallest valid workbook: one sheet, inline strings, no shared strings or styles.
  def write_xlsx(path, rows)
    sheet_rows = rows.each_with_index.map do |row, r|
      cells = row.each_with_index.map do |value, c|
        %(<c r="#{("A".ord + c).chr}#{r + 1}" t="inlineStr"><is><t>#{value}</t></is></c>)
      end
      %(<row r="#{r + 1}">#{cells.join}</row>)
    end
    files = {
      "[Content_Types].xml" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
      XML
      "_rels/.rels" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
      XML
      "xl/workbook.xml" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="Items" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
      XML
      "xl/_rels/workbook.xml.rels" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
      XML
      "xl/worksheets/sheet1.xml" => <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>#{sheet_rows.join}</sheetData>
        </worksheet>
      XML
    }
    Zip::OutputStream.open(path) do |zip|
      files.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end
  end
end

require 'zip/zipfilesystem'
require 'spreadsheet'
require 'roo'

module HQMF
  module BlackList
    class Parser

      CODE_SYSTEM_INDEX=0
      CODE_INDEX=1
      DESCRIPTION_INDEX=2

      # pull all the value sets and fill out the parents
      def parse(file_path)

        book = HQMF::ValueSet::Parser.book_by_format(file_path)

        results = []
        (0...book.sheets.length).each do |sheet_index|
          book.default_sheet=book.sheets[sheet_index]
          (2..book.last_row).each do |row_index|
            row = book.row(row_index)
            results << {code_system_name: row[CODE_SYSTEM_INDEX], code: row[CODE_INDEX].strip, description: row[DESCRIPTION_INDEX]}
          end
        end

        results

      end

    end
  end
end

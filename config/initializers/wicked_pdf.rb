# frozen_string_literal: true

WickedPdf.configure do |config|
  config.exe_path = `which wkhtmltopdf`.strip
  # config.layout = 'pdf.html'
end

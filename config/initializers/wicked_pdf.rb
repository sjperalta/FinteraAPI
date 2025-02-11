WickedPdf.configure do |config|
  config.exe_path = `which wkhtmltopdf`.strip
  #config.layout = 'pdf.html'
end

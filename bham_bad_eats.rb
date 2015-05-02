require 'rubygems'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 't'
require 'pry'

# get most recent sub-85 inspection record date
last_inspection_date = Date.today
begin
  last_inspection_date = Date.strptime(File.open('last_inspection_hit.txt', &:readline).strip, '%m/%d/%Y')
rescue
  puts 'There was a problem reading the last inspection hit date. Make sure the last_inspection_hit.txt file exists and that it contains the date of the last hit that was recorded.'
  exit 1
end

DOC_ROOT = 'http://www.jcdh.org/EH/FnL/'
doc = Nokogiri::HTML(open(DOC_ROOT + 'FnL03.aspx'))

score_table = doc.search("table[@id='ctl00_BodyContent_gvFoodScores']")
rows = score_table.search('tr')

rows.reverse.each_with_index do |tr,i|
  # get inspection score
  score = tr.children[5].text

  # skip header row
  next if score == 'Score'

  # get inspection date
  inspection_date = tr.children[6].text

  # if new record
  current_inspection_date = Date.strptime(inspection_date, '%m/%d/%Y')
  if current_inspection_date > last_inspection_date
    # if less than 85 and not the header row
    if score.to_i < 85
      # get establishment
      establishment = tr.children[2].text

      # get inspection report link
      link = DOC_ROOT + tr.children[5].search('a').attribute('href').value

      puts "#{score} :: #{inspection_date} :: #{establishment} :: #{link}"

      # post tweet
      cmd = "t update \"#{establishment} scored #{score} on #{inspection_date} #{link}\""
      system(cmd)

      # write hit date to file
      cmd = "echo #{inspection_date} > last_inspection_hit.txt"
      system(cmd)
    end
  end
end

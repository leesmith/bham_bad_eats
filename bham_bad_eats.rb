#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 't'
require 'pry'

DOC_ROOT = 'http://www.jcdh.org/EH/FnL/'

# Define inspection struct
InspectionReport = Struct.new(:inspection_date, :score, :establishment, :link, :permit_number, :inspection_number) do
  def to_tweet
    "#{establishment} scored #{score} on #{inspection_date} #{link}"
  end

  def to_s
    "#{score} :: #{inspection_date} :: #{establishment} :: #{permit_number} :: #{inspection_number} :: #{link}"
  end
end

# get most recent sub-85 inspection record date
last_inspection_date = nil
begin
  last_inspection_date = Date.strptime(File.open('last_inspection_date.txt', &:readline).strip, '%Y-%m-%d')
rescue
  puts 'There was a problem reading the last inspection hit date. Make sure the last_inspection_hit.txt file exists and that it contains the date (yyyy-mm-dd) of the last hit that was recorded.'
  exit 1
end

doc = Nokogiri::HTML(open(DOC_ROOT + 'FnL03.aspx'))
score_table = doc.search("table[@id='ctl00_BodyContent_gvFoodScores']")
rows = score_table.search('tr')

inspections = []
rows.each_with_index do |tr, i|
  # skip header row
  next if i == 0

  score = tr.children[5].text.to_i
  inspection_date = Date.strptime(tr.children[6].text, '%m/%d/%Y')
  establishment = tr.children[2].text
  permit_number = tr.children[5].search('a').attribute('href').value[/PermitNbr=\d+/].split('=').last
  inspection_number = tr.children[5].search('a').attribute('href').value[/InspNbr=\d+/].split('=').last
  link = "#{DOC_ROOT}FnL04.aspx?PermitNbr=#{permit_number}&InspNbr=#{inspection_number}"
  inspections << InspectionReport.new(inspection_date, score, establishment, link, permit_number, inspection_number)
end

# sort in ascending order
inspections.sort! { |a,b| a.inspection_date <=> b.inspection_date }

# tweet sub-85 inspections
inspections.each do |inspection|
  if (inspection.inspection_date > last_inspection_date) && (inspection.score < 85)
    puts inspection.to_s

    # post tweet
    cmd = "t update \"#{inspection.to_tweet}\""
    puts cmd
    system(cmd)
  end
end

# write last inspection date to file
cmd = "echo #{inspections.last.inspection_date} > last_inspection_date.txt"
puts cmd
system(cmd)

#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 't'
require 'pry'

puts "========== #{Time.now} Start =========="
DOC_ROOT = 'http://www.jcdh.org/EH/FnL/'

# Define inspection struct
InspectionReport = Struct.new(:inspection_date, :score, :establishment, :link, :permit_number, :inspection_number) do
  def to_a
    [inspection_date,score,establishment,link,permit_number,inspection_number]
  end

  def to_tweet
    "#{establishment} scored #{score} on #{inspection_date} #{link}"
  end

  def to_s
    "#{score} :: #{inspection_date} :: #{establishment} :: #{permit_number} :: #{inspection_number} :: #{link}"
  end
end

# build inspection history
inspection_history = []
CSV.foreach('history.csv') do |row|
  inspection_date = row[0]
  inspection_date = Date.strptime(row[0], '%Y-%m-%d')
  score = row[1].to_i
  establishment = row[2]
  link = row[3]
  permit_number = row[4].to_i
  inspection_number = row[5].to_i
  inspection_history << InspectionReport.new(inspection_date, score, establishment, link, permit_number, inspection_number)
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
  permit_number = tr.children[5].search('a').attribute('href').value[/PermitNbr=\d+/].split('=').last.to_i
  inspection_number = tr.children[5].search('a').attribute('href').value[/InspNbr=\d+/].split('=').last.to_i
  link = "#{DOC_ROOT}FnL04.aspx?PermitNbr=#{permit_number}&InspNbr=#{inspection_number}"
  inspections << InspectionReport.new(inspection_date, score, establishment, link, permit_number, inspection_number)
end

# sort in ascending order
inspections.sort! { |a,b| a.inspection_date <=> b.inspection_date }

# tweet sub-85 inspections
sub_85_inspections = []
inspections.each do |inspection|
  if (!inspection_history.include?(inspection)) && (inspection.score < 85)
    sub_85_inspections << inspection
    puts inspection.to_s

    # specify twitter acount to use
    cmd = "t set active Bham_Bad_Eats"
    system(cmd)

    # post tweet
    cmd = "t update \"#{inspection.to_tweet}\""
    puts cmd
    system(cmd)
  end
end

# write sub_85_inspections to history
if sub_85_inspections.count > 0
  CSV.open('history.csv','a+') do |csv|
    sub_85_inspections.each do |hit|
      csv << hit.to_a
    end
  end
end

puts "========== #{Time.now} Done! =========="
exit 0

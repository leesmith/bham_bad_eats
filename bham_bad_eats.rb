#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'csv'
require 'open-uri'

puts "========== #{Time.now} Start =========="
DOC_ROOT = 'https://webapps.jcdh.org/scores/ehfs/'

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

doc = Nokogiri::HTML(open(DOC_ROOT + 'foodservicescores.aspx'))
score_table = doc.search("table[@id='MainContent_gvFoodScores']")
rows = score_table.search('tr')

inspections = []
rows.each_with_index do |tr, i|
  # skip header row
  next if i == 0
  # skip footer row
  # break if i == (rows.size - 2)

  permit_number = tr.children[1].text.to_i
  score = tr.children[2].text.to_i
  inspection_number = tr.children[2].search('a').attribute('href').value[/InspNbr=\d+/].split('=').last.to_i
  link = DOC_ROOT + tr.children[2].search('a').attribute('href').value
  establishment = tr.children[3].text.strip.gsub(/\s+/, ' ')
  inspection_date = Date.strptime(tr.children[4].text, '%m/%d/%Y')
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

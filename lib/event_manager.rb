require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  number = number.to_s.scan(/\d/).join

  if number.length < 10 || number.length > 11
    '0000000000'
  elsif number.length == 11 && number[0] == '1'
    number[1..10]
  elsif number.length == 11 && number[0] != '1'
    '0000000000'
  else
    number
  end

end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def most_active_hours(hours)
  hour_counts = []

  hours.each do |h|
    hour_counts.push(hours.count(h))
  end

  max_occurence = hour_counts.uniq.max

  common_hours = hours.select { |h| hours.count(h) == max_occurence }.uniq

  common_hours = common_hours.map { |h| h.to_s.concat(':00')}

  [common_hours, max_occurence]
end

def most_active_days(days)
  # common_day = days.max_by { |d| days.count(d) }
  day_counts = []

  days.each { |d| day_counts.push(days.count(d)) }

  max_occurence = day_counts.uniq.max

  common_days = days.select { |d| days.count(d) == max_occurence }.uniq

  [common_days, max_occurence]
end

def print_most_active_times(hours, days)
  puts "The most common hour(s) of registration: #{hours[0].join(', ')}, with a max user count of #{hours[1]}."

  puts "The most common Day(s) of regustration: #{days[0].join(', ')}, with a max user count of #{days[1]}."
end

puts 'Event Manager Initialized!'

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_hours_arr = []
reg_days_arr = []

contents.each do |row|
  id = row[0]

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])

  reg_hour = Time.strptime(row[:regdate], '%m/%d/%Y %k:%M').hour

  reg_hours_arr.push(reg_hour)

  reg_day = Date::DAYNAMES[Date.strptime(row[:regdate], '%m/%d/%y').wday]

  reg_days_arr.push(reg_day)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

print_most_active_times(most_active_hours(reg_hours_arr), most_active_days(reg_days_arr))

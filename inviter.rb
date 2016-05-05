#!/home/ec2-user/.rbenv/shims/ruby

require 'rubygems'
require 'redis'
require 'open-uri'
require 'json'

# Find your API key at https://admin.typeform.com/account
typeform_api_key = ""
typeform_form_id = ""
# Find your Form ID at https://yoursubdomain.typeform.com/to/YOUR_FORM_ID
typeform_email_field = "email_20306303"
typeform_firstname_field = "textfield_20306301"
#@ Adding custom fields for our app
typeform_lastname_field = "textfield_20306302"
typeform_degree_field = "dropdown_21412378"
# Find these on your form. Right click -> Inspect -> look at the `id` of the `<li>` element.
#@ Adding custom fields for our app
#@ Commenting out, will use logic to auto enroll in channels rather than user choice
#typeform_channels_field = ENV["TYPEFORM_CHANNELS_FIELD"]
#typeform_channels_names = ENV["TYPEFORM_CHANNELS_NAMES"].split(',')

# Pull in the list of email addresses already invited to Slack
redis = Redis.new
previous_emails = redis.get("previously_invited_emails")

if previous_emails.nil?
  previously_invited_emails = Array.new
else
  previously_invited_emails = JSON.parse(previous_emails)
end

# SLACK_DOMAIN.slack.com
slack_domain = "wguit"
# Generate a token at https://api.slack.com/web
slack_auth_token = ""
# This is a little advanced:
# To get the Channel IDs, you need to ask the Slack API. Paste this into Terminal:
#
# curl -X POST https://slack.com/api/channels.list?token=SLACK_API_KEY
#
# Copy the output, and find the channel IDs that correspond with the channel
# names you'd like to use. They look like C0XXXXXXX.
#
# Set your environment variable with the SAME NUMBER of channels in your
# TYPEFORM_CHANNELS_FIELD and in the SAME ORDER. Separated by a comma.
#@ TODO:Tweak this to work
#slack_channels = ENV["SLACK_CHANNELS"].split(',')

###############################################################################
#@ Added hardcoded channels for now
#@ TODO: Use logic to pull group info from slack directly
all_groups_channels = "C14D1H19P,C14CFRRTL,C14UTM5U5,C0Z77BT4M,C10405258,C0Z77BT8V,C14A5BH0Q,C15093NGK"
bsit_channels = "C14CRHWBA,C14UM3XCZ,C0ZLX9F0B,C14CTP2G0,C14CVGZ71,C151NCWD6,#{all_groups_channels}"
netadmin_channels = "C14CUB3J9,C14UM3XCZ,C0ZLX9F0B,C14CTP2G0,C14CWTFQD,C14CVGZ71,C151NCWD6,#{all_groups_channels}"
netsec_channels = "C14CHT5NG,C14UM3XCZ,C0ZLX9F0B,C14BDHK43,C14CTP2G0,C14CVGZ71,C151NCWD6,C15093NGK,#{all_groups_channels}"
swdev_channels = "C14CZQ3H7,C14UM3XCZ,C0ZLX9F0B,C14CTP2G0,C14CVGZ71,C151NCWD6,#{all_groups_channels}"
health_channels = "C151NCWD6,#{all_groups_channels}"
msprog_channels = "C14CULDV5,#{all_groups_channels}"

#@TODO: Add logic to ensure the offset actually makes sense
offset = previously_invited_emails.count;

typeform_api_url = "https://api.typeform.com/v0/form/#{typeform_form_id}?key=#{typeform_api_key}&completed=true&offset=#{offset}"
typeform_data = JSON.parse(open(typeform_api_url).read)

puts "#{Time.now.strftime("%B %d, %Y: %r")} - Using URL: #{typeform_api_url}"

users_to_invite = Array.new
#slack_channels_array = Hash[typeform_channels_names.zip slack_channels]

typeform_data['responses'].each do |response|
  user = Hash.new
  user['email'] = response['answers'][typeform_email_field]
  # modified to include first, last, and degree
  user['firstname'] = response['answers'][typeform_firstname_field]
  user['lastname'] = response['answers'][typeform_lastname_field]
  user['degree'] = response['answers'][typeform_degree_field]
#@ TODO: Change this to do logic with the degree and set the channels
#@ Commenting out old code, which allows users to select what channels they wnat to join
#@ We can still allow user choice for the default, but am starting with assigning based on degree
#@ since that is what we wanted originally
  # unless typeform_channels_field.nil?
  #   channels = response['answers'].select {|k, v| k.include? typeform_channels_field}.values.select {|c| !c.empty?}
  #   default_channels = slack_channels_array.select {|k, v| channels.include? k}.values
  #   user['channels'] = default_channels
  # else
  #   user['channels'] = Array.new
  # end

  #@ As of now, I am hard coding the rooms we eventually decide on, however, if we like this and it works
  #@ We can script in more advanced logic to scrape the JSON return for the channels and put them in
  case user['degree']
  when "B.S. IT"
    user['channels'] = bsit_channels
  when "B.S. IT - Network Administration"
    user['channels'] = netadmin_channels
  when "B.S. IT – Security"
    user['channels'] = netsec_channels
  when "B.S. Software Development"
    user['channels'] = swdev_channels
  when "B.S. Health Informatics"
    user['channels'] = health_channels
  when /^M/
    user['channels'] = msprog_channels
  when "Undecided"
    user['channels'] = all_groups_channels
  end

  if !previously_invited_emails.include? user['email']
    users_to_invite.push(user)
  end
end

slack_invite_url = "https://#{slack_domain}.slack.com/api/users.admin.invite?t=#{Time.now}"

#@ Edited to allow for first and last name, as well as degree. I think this is just a log output, but good to have
users_to_invite.each do |user|
  puts "#{Time.now.strftime("%B %d, %Y: %r")} - #{user['firstname']} #{user['lastname']} (#{user['email']}) #{user['degree']} - Inviting to #{slack_domain}..."

  #@ Edited to allow for first/last, as well as inserting the Degree into the 'title' field (aka What I do)
  slack_fields = {
    'email' => user['email'],
    'first_name' => user['firstname'],
    'last_name' => user['lastname'],
    'title' => user['degree'],
    'channels' => user['channels'],
    'token' => slack_auth_token,
    'set_active' => "true",
    '_attempts' => "1"
  }

  slack_params = URI.encode_www_form(slack_fields)
  slack_response = JSON.parse(open("#{slack_invite_url}&#{slack_params}").read)

  if slack_response['ok'] == true
    previously_invited_emails.push(user['email'])
    puts "Invite sent!"
  else
    puts "Uh oh! Couldn't add this person to #{slack_domain}. Error: #{slack_response['error']}"
  end
end

puts "#{Time.now.strftime("%B %d, %Y: %r")} Script done!"
redis.set("previously_invited_emails", previously_invited_emails.to_json)

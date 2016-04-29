#!/usr/bin/env ruby

require 'rubygems'
require 'dotenv'
require 'redis'
require 'open-uri'
require 'json'
Dotenv.load

# Find your API key at https://admin.typeform.com/account

# Find your Form ID at https://yoursubdomain.typeform.com/to/YOUR_FORM_ID

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

# Generate a token at https://api.slack.com/web

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

offset = previously_invited_emails.count;

typeform_api_url = "https://api.typeform.com/v0/form/#{typeform_form_id}?key=#{typeform_api_key}&completed=true&offset=#{offset}"

typeform_data = JSON.parse(open(typeform_api_url).read)

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
    user['channels'] = "C14NG07QQ,C14NHNVV5,C14NXM1AN"
  when "B.S. IT - Network Administration"
    user['channels'] = "C14NG07QQ,C14NHNVV5,C14NJQT24"
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

redis.set("previously_invited_emails", previously_invited_emails.to_json)

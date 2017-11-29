#!/home/ec2-user/.rbenv/shims/ruby
#!/usr/bin/env ruby
# There has been a problem where some people are not getting invited to the correct channel.
# During my investigation I have found some errors syncing my Redis db and TypeForm offset value
# Redis shows a lot less.
#
# Redis seems to be obsolete for this, slack can gracefully handle duplicate invitations by rejecting
# the duplicate and sending back an error code, so why not just use that?
# So This version I have removed the dependency of Redis and reworked the logic so that
# slack will be the authority on whether or not to invite someone, and the error message will now specify
# that this has happened, and to what user (first, last, email, major, channels)
require 'rubygems'
require 'open-uri'
require 'json'

# Find your API key at https://admin.typeform.com/account
typeform_api_key = ""
typeform_form_id = "wuOXg4"
# Find your Form ID at https://yoursubdomain.typeform.com/to/YOUR_FORM_ID
typeform_email_field = "email_20306303"
typeform_firstname_field = "textfield_20306301"
#@ Adding custom fields for our app
typeform_lastname_field = "textfield_20306302"
typeform_degree_field = "dropdown_21412378"

# SLACK_DOMAIN.slack.com
slack_domain = "wguit"
# Generate a token at https://api.slack.com/web
slack_auth_token = ""

#@ Added hardcoded channels for now
#@ TODO: Use logic to pull group info from slack directly
all_groups_channels = "C14D1H19P,C14CFRRTL,C14UTM5U5,C0Z77BT4M,C10405258,C0Z77BT8V,C14A5BH0Q,C15093NGK"
bsit_channels = "C14CRHWBA,C14UM3XCZ,C0ZLX9F0B,C14CTP2G0,C14CVGZ71,C151NCWD6,#{all_groups_channels}"
netadmin_channels = "C14CUB3J9,C14UM3XCZ,C0ZLX9F0B,C14CTP2G0,C14CWTFQD,C14CVGZ71,C151NCWD6,#{all_groups_channels}"
netsec_channels = "C14CHT5NG,C14UM3XCZ,C0ZLX9F0B,C14BDHK43,C14CTP2G0,C14CVGZ71,C151NCWD6,C15093NGK,#{all_groups_channels}"
swdev_channels = "C14CZQ3H7,C14UM3XCZ,C0ZLX9F0B,C14CTP2G0,C14CVGZ71,C151NCWD6,#{all_groups_channels}"
health_channels = "C151NCWD6,#{all_groups_channels}"
msprog_channels = "C14CULDV5,#{all_groups_channels}"
dmda_channels = "C1FAEDR5F,C14UM3XCZ,#{all_groups_channels}"

# original url - typeform_api_url = "https://api.typeform.com/v0/form/#{typeform_form_id}?key=#{typeform_api_key}&completed=true&offset=#{offset}"
# Set a variable to now
sinceTime = Time.now.utc
# Time math, subtract 5 minute and one second from now.
sinceTime = sinceTime - (302)
puts "#{Time.now.strftime("%B %d, %Y: %r")} - Using Time: #{sinceTime.to_i}"
# use the time and other TypeForm info to pull new members, to_i formats time in Epoc/Unix time
typeform_api_url = "https://api.typeform.com/v0/form/#{typeform_form_id}?key=#{typeform_api_key}&completed=true&since=#{sinceTime.to_i}"

# Debug line, testing my entry so I dont have to keep filling out form
# Parse the JSON return
typeform_data = JSON.parse(open(typeform_api_url).read)

#Debugging
puts "#{Time.now.strftime("%B %d, %Y: %r")} - Using URL: #{typeform_api_url}"

# Create an array of new users that need to be invited
users_to_invite = Array.new
# Cycle through the Typeform response to extract user info
typeform_data['responses'].each do |response|
  user = Hash.new
  user['email'] = response['answers'][typeform_email_field]
  user['firstname'] = response['answers'][typeform_firstname_field]
  user['lastname'] = response['answers'][typeform_lastname_field]
  user['degree'] = response['answers'][typeform_degree_field]
  puts "DEBUG: First: #{user['firstname']} Last: #{user['lastname']} Email: #{user['email']} Degree: #{user['degree']}"

  #@ As of now, I am hard coding the rooms we eventually decide on, however, if we like this and it works
  #@ We can script in more advanced logic to scrape the JSON return for the channels and put them in
  case user['degree']
  when "B.S. IT"
    user['channels'] = bsit_channels
    puts "User in BSIT Channels"
  when "B.S. IT - Network Administration"
    user['channels'] = netadmin_channels
    puts "User in NetAdmin channels"
  when /Cybersecurity$/
    user['channels'] = netsec_channels
    puts "User in Sec channels"
  when /Security$/
    user['channels'] = netsec_channels
    puts "User in Sec channels"

  when "B.S. Software Development"
    user['channels'] = swdev_channels
    puts "User in swdev"
  when "B.S. Health Informatics"
    user['channels'] = health_channels
    puts "User in health"
  when "B.S. Data Management/Data Analytics"
    user['channels'] = dmda_channels
    puts "User in DMDA"
  when /^M/
    user['channels'] = msprog_channels
    puts "User a master"
  when "Undecided"
    user['channels'] = all_groups_channels
    puts "User don't know"
  else
    puts "\"#{user['degree']}\" = \"B.S. IT - Security\""
    puts "#{Time.now.strftime("%B %d, %Y: %r")} - Uh oh, something went wrong with your channel assignment for #{user['firstname']} #{user['lastname']} (#{user['email']}) #{user['degree']} ..."
  end
  # Now that we have all the relevant data for this user, lets push them into the array
  users_to_invite.push(user)
end

# Previous version used Time.now but neglected to convert to unix time
slack_invite_url = "https://#{slack_domain}.slack.com/api/users.admin.invite?t=#{Time.now.utc.to_i}"

# Lets cycle through this array we created of users to be invited, and actually invite them!
users_to_invite.each do |user|
  # Modified to include the state subdomains
  if ['wgu.edu', 'my.wgu.edu', 'indiana.wgu.edu', 'washington.wgu.edu', 'texas.wgu.edu', 'missouri.wgu.edu', 'tennessee.wgu.edu', 'nevada.wgu.edu'].include? user['email'].split('@').last
    puts "#{Time.now.strftime("%B %d, %Y: %r")} - #{user['firstname']} #{user['lastname']} (#{user['email']}) #{user['degree']} - Inviting to #{slack_domain}..."
    puts "Granted access to channels: #{user['channels']}"

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
      puts "Invite sent!"
    else
      puts "#{Time.now.strftime("%B %d, %Y: %r")} - Uh oh! Couldn't add #{user['firstname']} #{user['lastname']} (#{user['email']}) to #{slack_domain}. Error: #{slack_response['error']}"
    end
  else
    puts "#{Time.now.strftime("%B %d, %Y: %r")} - #{user['firstname']} #{user['lastname']} (#{user['email']}) #{user['degree']} - Email Domain Mismatch. Not WGU student email. Discarding..."
  end
end

puts "#{Time.now.strftime("%B %d, %Y: %r")} Script done!"

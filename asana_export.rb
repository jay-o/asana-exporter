require "rubygems"
require "net/https"
require "json"
require 'csv'

api_key = 'API123!@#$'

# List project IDs you want to pull from
project_ids = ['01234456789','9876543210','121223233434','454556566767']

# Go through project_id list 1 at a time 
project_ids.each do |project|

  # Basic setup for http request
  baseurl = 'https://app.asana.com/api/1.0' # We'll use this in each request so we only set it once here
  path    = 'projects'
  proj_id = project # Project ID we're currently on from list on line #9
  address = "#{baseurl}/#{path}/#{proj_id}" # put it all together for the URI.parse step

  # Setup for HTTPS connection
  uri = URI.parse(address)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  # Make the request & Authenticate
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth(api_key, '') 
  response = http.request(request)

  # Grab JSON blob
  h = JSON.parse response.body

  # Print Project Name & set variable to use later
  project_name = ''
  h.each do |key, value|
    project_name = value['name']
    puts project_name
  end

  # Get tasks for the project project
  path    = 'projects'
  address = "#{baseurl}/#{path}/#{proj_id}/tasks?opt_fields=id,name,notes"

  # Make request with new paths
  uri = URI.parse(address)
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth(api_key, '')
  response = http.request(request)

  # Grab JSON data
  tasks = JSON.parse response.body
  
  # Create array so we can store Task IDs from this project
  project_task_ids = []

  # Create CSV file to dump data
  file_name = "files/asana-#{project_name}-data.csv"
  CSV.open(file_name, 'wb') do |csv|
    # Set column names in first row
    csv << ['Project Name', 'Task ID', 'Project Sub Category', 'Task Name', 'Description']

    # Loop through each task and grab ID, Name, Note
    tasks.each do |key, value|
      proj_sub_cat = ''
      value.each do |a|
        if a['name'][-1,1] == ':'
          proj_sub_cat = a['name']
        else
          task_id = a['id']
          task_name = a['name']
          task_note = a['notes']

          # Add to CSV
          csv << [project_name, task_id, proj_sub_cat, task_name,task_note]
          # Add to list of tasks for step 3
          project_task_ids.push <<  task_id
        end
      end
    end
  end
 
  # Create CSV for Task Comments
  file_name = "files/asana-#{project_name}-task-details.csv"
  CSV.open(file_name, 'wb') do |csv|
    csv << ['Project Name', 'Task ID', 'Comment ID', 'Comment Created At', 'Comment', 'Commenter']

    # Setup Counter to monitor how far through the task we are
    count = project_task_ids.count
    counter = 0

    # Loop through each task in the array we created, grab all stories, and put in CSV
    project_task_ids.each do |task_id|
      counter = counter + 1 # Prints how far along we are in console
      puts "#{counter} of #{count} tasks"

      # Prep for request
      path    = 'tasks'
      address = "#{baseurl}/#{path}/#{task_id}/stories"

      # Authenticate and make request
      uri = URI.parse(address)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(api_key, '')
      response = http.request(request)

      # Grab JSON blob for stories for each task
      stories = JSON.parse response.body

      # Evaluate each story. If it's a comment then store it in CSV, else ignore 
      stories.each do |key, value|
        value.each do |story|
          if story['type'] == 'comment'
            comment_id = story['id']
            comment_created_at = story['created_at']
            comment = story['text']
            commenter = story['name']
            csv << [project_name, task_id, comment_id, comment_created_at, comment, commenter ]
          end
        end
      end
    end
  end
end

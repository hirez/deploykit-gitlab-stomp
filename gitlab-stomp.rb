require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'json'
require 'yaml'
require 'stomp'
require 'syslog'



settings = YAML.load_file("/etc/gitlab-stomp/gitlab-stomp.yaml")

Syslog.open('gitlab-stomp', Syslog::LOG_CONS, Syslog::LOG_DAEMON)

trigger_topic = settings['trigger-topic']
report_topic = settings['report-topic']
stompconnector = settings['stompconnector']


post '/' do
  push = JSON.parse(env['rack.input'].read)

  type = 'push'
  type = push['object_kind'] if push['object_kind']

  case type
  when 'push'
    reponame = push['repository']['name']
    oldrev = push['before']
    newrev = push['after']
    refname = push['ref']
  
    subject = "[#{reponame}] #{refname} #{newrev}"
    body = "repo: #{reponame}\noldrev: #{oldrev}\nnewrev: #{newrev}\nrefname: #{refname}\n"

    push['commits'].each do |flob|
      body2 = " commit #{flob['id']}\nAuthor: #{flob['author']['email']}\nDate: #{flob['timestamp']}\n\t#{flob['message']}\n\n"
      body.concat(body2)
    end

    client = Stomp::Client.new(stompconnector)
    if client
      client.publish("/topic/#{trigger_topic}",body, {:subject => subject})
      eventdetail = "#{subject} (webhook)"
      client.publish("/topic/#{report_topic}",eventdetail, {:subject => "Talking to eventbot"})
      Syslog.info("Pushed change: %s",subject)
      client.close
    end

  when 'merge_request'
    source = push['object_attributes']['source_branch']
    target = push['object_attributes']['target_branch']
    state = push['object_attributes']['state']

    eventdetail = "Merge request: #{source} -> #{target} #{state}"

    client = Stomp::Client.new(stompconnector)
    if client
      client.publish("/topic/#{report_topic}",eventdetail, {:subject => "Talking to eventbot"})
      client.close
    end
  end
end

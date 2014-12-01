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

    url = push['repository']['url'].match(/\/(.*)\.git/)
    reponame = url[1] 
    #puts "This is a commit for #{project}"

    oldrev = push['before']
    newrev = push['after']
    refname = push['ref']
    user = push['user_name']
    repo_homepage = push['repository']['homepage']
    commit_count = 'unknown'

    subject = "[#{reponame}] #{refname} #{newrev}"
    body = "repo: #{reponame}\noldrev: #{oldrev}\nnewrev: #{newrev}\nrefname: #{refname}\n"


    if !push['commits'].nil?
      push['commits'].each do |flob|
        body2 = " commit #{flob['id']}\nAuthor: #{flob['author']['email']}\nDate: #{flob['timestamp']}\n\t#{flob['message']}\n\n"
        body.concat(body2)
      end
      commit_count=commits.length
    end

    client = Stomp::Client.new(stompconnector)
    if client
      client.publish("/topic/#{trigger_topic}",body, {:subject => subject})

      # Create a more human friendly version of the published events that include a url to the latest change
      # Example: John Smith pushed 4 commit(s) to myrepo - http://gitlab.example.org/myrepo/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7
      eventdetail = "#{user} pushed #{commit_count} commit(s) to #{reponame} - #{repo_homepage}/commits/#{newrev} (webhook)"
      client.publish("/topic/#{report_topic}",eventdetail, {:subject => "Talking to eventbot"})
      
      Syslog.info("Pushed change: %s",subject)
      client.close
    end

  when 'merge_request'
    source = push['object_attributes']['source_branch']
    sourcerepo = 'unknown'
    target = push['object_attributes']['target_branch']
    targetrepo = 'unknown'
    state = push['object_attributes']['state']
    user = 'unknown'

    # Users only exist in gitlab 7.5.0+
    if !push['user'].nil?
      user = push['user']['name']
    end
    # Source and target only exists in 7.4.0+
    if !push['object_attributes']['source'].nil?
      sourcerepo = push['object_attributes']['source']['namespace']
    end
    if !push['object_attributes']['target'].nil?
      targetrepo = push['object_attributes']['target']['namespace']
    end

    # Amazingly, its really hard to work out what the Merge Request url is
    eventdetail = "Merge request (#{push['object_attributes']['title']}) #{state} by #{user}: #{sourcerepo}:#{source} -> #{targetrepo}:#{target}"

    client = Stomp::Client.new(stompconnector)
    if client
      client.publish("/topic/#{report_topic}",eventdetail, {:subject => "Talking to eventbot"})
      client.close
    end
  end
end

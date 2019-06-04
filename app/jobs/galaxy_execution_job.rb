require 'pty'

class GalaxyExecutionJob < SeekJob
  attr_reader :data_file_id, :workflow_id, :execution_id

  def initialize(data_file,workflow,execution_id)
    @data_file_id = data_file.id
    @workflow_id = workflow.id
    @execution_id = execution_id
  end

  def perform_job(item)
    item.update_attribute(:status, GalaxyExecutionQueueItem::RUNNING)
    execute_galaxy_script(item)
    item.update_attribute(:status, GalaxyExecutionQueueItem::FINISHED)
  end

  def gather_items
    [queued_items.first].compact
  end

  def timelimit
    1.day
  end

  def follow_on_job?
    queued_items.any?
  end

  def follow_on_delay
    0.5.second
  end

  private

  def queued_items
    GalaxyExecutionQueueItem.where(data_file_id: data_file_id,status: GalaxyExecutionQueueItem::QUEUED,execution_id: execution_id)
  end

  def execute_galaxy_script(item)
    cmd = command(item)
    puts "command = #{cmd}"
    begin
      PTY.spawn( cmd ) do |stdout, stdin, pid|
        begin
          # Do stuff with the output here. Just printing to show it works
          stdout.each { |line| handle_response(line,item) }
        rescue Errno::EIO
          puts "Errno:EIO error found"
        end
      end
    rescue PTY::ChildExited
      puts "The child process exited!"
    end

  end

  def handle_response(line,item)
    puts line
    begin
      j = JSON.parse(line)
      msg = j['status']
      item.update_attribute(:current_status,msg)
      if j['data'] && j['data']['history_id']
        item.update_attribute(:history_id,j['data']['history_id'])
      end
    rescue JSON::ParserError
      puts "not JSON, ignoring: #{line}"
    end
  end

  def command(item)
    args = command_argument_json(item)
    "python3 #{Rails.root}/script/galaxy.py '#{args}'"
  end

  def command_argument_json(item)
    json = {}
    json['url']=item.person.galaxy_instance
    json['api_key']=item.person.galaxy_api_key
    json['workflow_id']=workflow.galaxy_id
    json['data']={}
    json['data']['forward']=item.sample.get_attribute('fastq_forward')
    json['data']['reverse']=item.sample.get_attribute('fastq_reverse')
    JSON(json).to_s
  end

  def workflow
    Workflow.find(workflow_id)
  end

end
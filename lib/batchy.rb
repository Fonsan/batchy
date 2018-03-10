require 'aws-sdk-batch'

class Batchy
  def initialize(client)
    @client = client
  end

  STATES = %w(SUBMITTED PENDING RUNNABLE STARTING RUNNING SUCCEEDED FAILED)
  DESCRIBE_JOB_LIMIT = 100

  def jobs(queue_name, *states)
    return to_enum(:jobs, queue_name, *states) unless block_given?
    job_summaries(queue_name, *states).each_slice(DESCRIBE_JOB_LIMIT) do |slice|
      ids = slice.map(&:job_id)
      @client.describe_jobs(jobs: ids).jobs.each do |job|
        yield job
      end
    end
  end

  def job_summaries(queue_name, *states)
    return to_enum(:job_summaries, queue_name, *states) unless block_given?
    states = STATES if states.empty?
    states.each do |state|
      token = nil
      while page = @client.list_jobs(job_queue: queue_name, job_status: state, next_token: token)
        page.each do |job_list|
          job_list.job_summary_list.each do |job_summary|
            yield job_summary
          end
        end
        break unless page.next_token
        break if page.next_token == token
        token = page.next_token
      end
    end
  end
end

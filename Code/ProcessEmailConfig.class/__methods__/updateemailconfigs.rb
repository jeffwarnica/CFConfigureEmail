def log(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def dump_root()
  log(:info, "Begin $evm.root.attributes")
  $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}") }
  log(:info, "End $evm.root.attributes")
  log(:info, "")
end

def error(msg)
  log(:error, "#{msg}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg
  exit MIQ_OK
end

def retry_method(msg, retry_time=1.minute)
  log(:warn, "Retrying in #{retry_time} seconds: [#{msg}]")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_reason'] = msg.to_s
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

def instantiate(uri)
  result = $evm.instantiate(uri)
  error("Failed to execute #{uri}") unless result

  case result['result']
    when 'error'
      error(result['reason'])
    when 'retry'
      retry_method(result['reason'])
  end

  result
end

def update_instances(ae_uri)
  result = $evm.instance_get(ae_uri)
  log(:info, "Initial values for instance: [#{ae_uri}] : [#{result}]")

  attrs = { "from_email_address" => @from_email_address,
            "to_email_address" => @to_email_address,
            "signature" => @signature }

  result2 = $evm.instance_update(ae_uri, attrs)
  log(:info, "Updated	 values for instance: [#{ae_uri  }] : [#{result2}]")
end


begin
  dump_root()

  @from_email_address = $evm.root['dialog_from_email_address'] || error('no dialog_from_email_address passed')
  @to_email_address = $evm.root['dialog_to_email_address'] || error('no dialog_to_email_address passed')
  @signature = $evm.root['dialog_signature'] || error('no dialog_signature passed')

  log(:info, "instances" + $evm.object['instances'].inspect)

  instances = $evm.object['instances']
  instances.each { |ae_uri| update_instances(ae_uri) }

#
# Set Ruby rescue behavior
#
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
ensure
  # nuke the service record regardless.
  $evm.root['service'].remove_from_vmdb

end

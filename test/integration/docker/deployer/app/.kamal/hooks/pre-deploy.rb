FileUtils.mkdir_p "/tmp/#{ENV.fetch('TEST_ID')}"
FileUtils.touch "/tmp/#{ENV.fetch('TEST_ID')}/pre-deploy.rb"

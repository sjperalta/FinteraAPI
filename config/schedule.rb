every 1.day, at: '12:00 am' do
  runner "CheckPaymentsOverdueJob.perform_now"
end

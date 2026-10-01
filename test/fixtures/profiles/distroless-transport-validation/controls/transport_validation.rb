control 'sanity' do
  impact 1.0
  title 'Runner sanity check'
  desc 'Confirm InSpec can evaluate a control after connecting'
  describe(1 + 1) do
    it { should eq 2 }
  end
end

control 'shell-dependent-command' do
  impact 1.0
  title 'Run a shell dependent command'
  desc 'Confirm shell-dependent commands run through the ephemeral helper'
  describe inspec.backend.run_command('cat /etc/os-release | grep "^ID="') do
    its('stdout') { should match(/ID="?debian"?/) }
  end
end

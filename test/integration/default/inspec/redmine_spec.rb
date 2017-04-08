control 'redmine-1' do
  title 'Forge Setup'
  desc 'Check that redmine is installed and running'

  describe file('/srv/redmine/current') do
    it { should be_symlink }
  end

  describe port(80) do
    it { should be_listening }
    its('protocols') { should include 'tcp'}
  end

  # port 80 HTML
  describe command('curl http://localhost:80') do
    its('exit_status') { should eq 0 }
    its('stdout') { should include '<title>Redmine</title>' }
  end

end

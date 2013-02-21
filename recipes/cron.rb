cron "fetch_changesets" do
  minute "*/30"
  command "/var/lib/gems/1.8/bin/bundle exec #{node.redmine.dir}/script/runner 'Repository.fetch_changesets' -e production"
  user "redmine"
end
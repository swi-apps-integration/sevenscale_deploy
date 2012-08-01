# Originally lifted from:
# http://github.com/vigetlabs/viget_deployment/tree/master/recipes/campfire.rb
#
# Usage:
#
#    campfire.register 'sevenscale', 'b8d9b31...', :room => 'crazypants', :ssl => true
#
namespace :campfire do
  set(:previous_current_revision) { raise "Previous current revision was never fetched" }

  # before 'deploy',                   'campfire:save_previous_current_revision'
  # before 'deploy:rollback:revision', 'campfire:save_previous_current_revision'

  def register(domain, token, config = {})
    begin
      require 'uri'
      require 'tinder'
    rescue LoadError
      return false # skip campfire stuff if tinder can't be required
    end

    short_domain = domain[/^([^\.]+)/, 1]

    speak = lambda do |message|
      campfire = Tinder::Campfire.new(domain, :ssl => config[:ssl], :token => token)
      room     = campfire.find_room_by_name(config[:room]) rescue nil

      if room
        room.speak message
      end
    end

    notify_error = lambda do
      if ex = $!
        message = "[CAP] %s's deploy of %s" % [
          ENV['USER'], fetch(:application),
        ]
        if stage = fetch(:rails_env, nil)
          message << " to #{stage}"
        end

        if ::Interrupt === ex
          message << " was canceled."
        else
          message << " failed with exception #{ex.class}: "
          if ex.message.to_s.length > 200
            message << ex.message.to_s[0..200] << "..."
          else
            message << ex.message.to_s
          end
        end

        speak.call message
      end
    end

    namespace short_domain do
      before 'deploy',            "campfire:#{short_domain}:notify_start"
      before 'deploy:migrations', "campfire:#{short_domain}:notify_start"
      after  'deploy',            "campfire:#{short_domain}:notify_finished"
      after  'deploy:migrations', "campfire:#{short_domain}:notify_finished"

      task :notify_start do
        deployer    = ENV['USER']
        deployed    = current_revision.to_s[0..7]
        deploying   = real_revision.to_s[0..7]
        github_repo = repository[/github.com:(.*)\.git$/, 1]
        compare_url = "http://github.com/#{github_repo}/compare/#{deployed}...#{deploying}"

        message = "[CAP] %s is deploying (%s..%s) of %s" % [
          ENV['USER'], deployed, deploying, fetch(:application),
        ]
        if stage = fetch(:rails_env, nil)
          message << " to #{stage}"
        end
        message << " with `cap #{ARGV.join(' ')}` (#{compare_url})"

        speak.call message

        # Make sure we say something if there's an error
        at_exit &notify_error
      end

      task :notify_finished do
        logger.debug "sending message to #{config[:room]} on #{short_domain} Campfire"

        message = "[CAP] %s's deploy of %s" % [
          ENV['USER'], fetch(:application),
        ]
        if stage = fetch(:rails_env, nil)
          message << " to #{stage}"
        end
        message << " is done."

        speak.call message
      end
    end
  end

  task :save_previous_current_revision do
    set(:previous_current_revision, (capture("cat #{current_path}/REVISION").chomp rescue nil))
  end
end

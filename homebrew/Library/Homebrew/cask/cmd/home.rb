# frozen_string_literal: true

module Cask
  class Cmd
    class Home < AbstractCommand
      def self.description
        "Opens the homepage of the given <cask>. If no cask is given, opens the Homebrew homepage."
      end

      def run
        # odeprecated "brew cask home", "brew home"

        if casks.none?
          odebug "Opening project homepage"
          self.class.open_url "https://brew.sh/"
        else
          casks.each do |cask|
            odebug "Opening homepage for Cask #{cask}"
            self.class.open_url cask.homepage
          end
        end
      end

      def self.open_url(url)
        SystemCommand.run!(OS::PATH_OPEN, args: ["--", url])
      end
    end
  end
end

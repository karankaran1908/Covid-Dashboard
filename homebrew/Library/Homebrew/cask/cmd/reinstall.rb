# frozen_string_literal: true

module Cask
  class Cmd
    class Reinstall < Install
      def self.description
        "Reinstalls the given <cask>."
      end

      def run
        self.class.reinstall_casks(
          *casks,
          binaries:       args.binaries?,
          verbose:        args.verbose?,
          force:          args.force?,
          skip_cask_deps: args.skip_cask_deps?,
          require_sha:    args.require_sha?,
          quarantine:     args.quarantine?,
        )
      end

      def self.reinstall_casks(
        *casks,
        verbose: false,
        force: false,
        skip_cask_deps: false,
        binaries: nil,
        require_sha: nil,
        quarantine: nil
      )

        options = {
          binaries:       binaries,
          verbose:        verbose,
          force:          force,
          skip_cask_deps: skip_cask_deps,
          require_sha:    require_sha,
          quarantine:     quarantine,
        }.compact

        options[:quarantine] = true if options[:quarantine].nil?

        casks.each do |cask|
          Installer.new(cask, **options).reinstall
        end
      end
    end
  end
end

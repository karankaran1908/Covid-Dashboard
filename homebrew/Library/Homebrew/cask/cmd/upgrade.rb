# frozen_string_literal: true

require "env_config"
require "cask/config"

module Cask
  class Cmd
    class Upgrade < AbstractCommand
      def self.description
        "Upgrades all outdated casks or the specified casks."
      end

      def self.parser
        super do
          switch "--force",
                 description: "Force overwriting existing files."
          switch "--skip-cask-deps",
                 description: "Skip installing cask dependencies."
          switch "--greedy",
                 description: "Also include casks which specify `auto_updates true` or `version :latest`."
          switch "--dry-run",
                 description: "Show what would be upgraded, but do not actually upgrade anything."
        end
      end

      def run
        verbose = ($stdout.tty? || args.verbose?) && !args.quiet?
        self.class.upgrade_casks(
          *casks,
          force:          args.force?,
          greedy:         args.greedy?,
          dry_run:        args.dry_run?,
          binaries:       args.binaries?,
          quarantine:     args.quarantine?,
          require_sha:    args.require_sha?,
          skip_cask_deps: args.skip_cask_deps?,
          verbose:        verbose,
        )
      end

      def self.upgrade_casks(
        *casks,
        force: false,
        greedy: false,
        dry_run: false,
        skip_cask_deps: false,
        verbose: false,
        binaries: nil,
        quarantine: nil,
        require_sha: nil
      )

        quarantine = true if quarantine.nil?

        outdated_casks = if casks.empty?
          Caskroom.casks.select do |cask|
            cask.outdated?(greedy)
          end
        else
          casks.select do |cask|
            raise CaskNotInstalledError, cask unless cask.installed? || force

            cask.outdated?(true)
          end
        end

        return if outdated_casks.empty?

        ohai "Casks with `auto_updates` or `version :latest` will not be upgraded" if casks.empty? && !greedy

        verb = dry_run ? "Would upgrade" : "Upgrading"
        oh1 "#{verb} #{outdated_casks.count} #{"outdated package".pluralize(outdated_casks.count)}:"

        caught_exceptions = []

        upgradable_casks = outdated_casks.map { |c| [CaskLoader.load(c.installed_caskfile), c] }

        puts upgradable_casks
          .map { |(old_cask, new_cask)| "#{new_cask.full_name} #{old_cask.version} -> #{new_cask.version}" }
          .join("\n")
        return if dry_run

        upgradable_casks.each do |(old_cask, new_cask)|
          upgrade_cask(
            old_cask, new_cask,
            binaries: binaries, force: force, skip_cask_deps: skip_cask_deps, verbose: verbose,
            quarantine: quarantine, require_sha: require_sha
          )
        rescue => e
          caught_exceptions << e.exception("#{new_cask.full_name}: #{e}")
          next
        end

        return if caught_exceptions.empty?
        raise MultipleCaskErrors, caught_exceptions if caught_exceptions.count > 1
        raise caught_exceptions.first if caught_exceptions.count == 1
      end

      def self.upgrade_cask(
        old_cask, new_cask,
        binaries:, force:, quarantine:, require_sha:, skip_cask_deps:, verbose:
      )
        odebug "Started upgrade process for Cask #{old_cask}"
        old_config = old_cask.config

        old_options = {
          binaries: binaries,
          verbose:  verbose,
          force:    force,
          upgrade:  true,
        }.compact

        old_cask_installer =
          Installer.new(old_cask, **old_options)

        new_cask.config = Config.global.merge(old_config)

        new_options = {
          binaries:       binaries,
          verbose:        verbose,
          force:          force,
          skip_cask_deps: skip_cask_deps,
          require_sha:    require_sha,
          upgrade:        true,
          quarantine:     quarantine,
        }.compact

        new_cask_installer =
          Installer.new(new_cask, **new_options)

        started_upgrade = false
        new_artifacts_installed = false

        begin
          oh1 "Upgrading #{Formatter.identifier(old_cask)}"

          # Start new Cask's installation steps
          new_cask_installer.check_conflicts

          puts new_cask_installer.caveats if new_cask_installer.caveats

          new_cask_installer.fetch

          # Move the old Cask's artifacts back to staging
          old_cask_installer.start_upgrade
          # And flag it so in case of error
          started_upgrade = true

          # Install the new Cask
          new_cask_installer.stage

          new_cask_installer.install_artifacts
          new_artifacts_installed = true

          # If successful, wipe the old Cask from staging
          old_cask_installer.finalize_upgrade
        rescue => e
          new_cask_installer.uninstall_artifacts if new_artifacts_installed
          new_cask_installer.purge_versioned_files
          old_cask_installer.revert_upgrade if started_upgrade
          raise e
        end
      end
    end
  end
end

# frozen_string_literal: true

module Cask
  class Cmd
    class List < AbstractCommand
      def self.description
        "Lists installed casks or the casks provided in the arguments."
      end

      def self.parser
        super do
          switch "-1",
                 description: "Force output to be one entry per line."
          switch "--versions",
                 description: "Show the version number the listed casks."
          switch "--full-name",
                 description: "Print casks with fully-qualified names."
          switch "--json",
                 description: "Print a JSON representation of the listed casks. "
        end
      end

      def run
        self.class.list_casks(
          *casks,
          json:      args.json?,
          one:       args.public_send(:'1?'),
          full_name: args.full_name?,
          versions:  args.versions?,
        )
      end

      def self.list_casks(*casks, json: false, one: false, full_name: false, versions: false)
        output = if casks.any?
          casks.each do |cask|
            raise CaskNotInstalledError, cask unless cask.installed?
          end
        else
          Caskroom.casks
        end

        if json
          puts JSON.generate(output.map(&:to_h))
        elsif one
          puts output.map(&:to_s)
        elsif full_name
          puts output.map(&:full_name).sort(&tap_and_name_comparison)
        elsif versions
          puts output.map(&method(:format_versioned))
        elsif !output.empty? && casks.any?
          puts output.map(&method(:list_artifacts))
        elsif !output.empty?
          puts Formatter.columns(output.map(&:to_s))
        end
      end

      def self.list_artifacts(cask)
        cask.artifacts.group_by(&:class).each do |klass, artifacts|
          next unless klass.respond_to?(:english_description)

          return "==> #{klass.english_description}", artifacts.map(&:summarize_installed)
        end
      end

      def self.format_versioned(cask)
        cask.to_s.concat(cask.versions.map(&:to_s).join(" ").prepend(" "))
      end
    end
  end
end

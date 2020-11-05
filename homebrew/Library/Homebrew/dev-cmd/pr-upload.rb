# frozen_string_literal: true

require "cli/parser"
require "bintray"

module Homebrew
  module_function

  def pr_upload_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `pr-upload` [<options>]

        Apply the bottle commit and publish bottles to Bintray.
      EOS
      switch "--no-publish",
             description: "Apply the bottle commit and upload the bottles, but don't publish them."
      switch "--keep-old",
             description: "If the formula specifies a rebuild version, " \
                          "attempt to preserve its value in the generated DSL."
      switch "-n", "--dry-run",
             description: "Print what would be done rather than doing it."
      switch "--warn-on-upload-failure",
             description: "Warn instead of raising an error if the bottle upload fails. "\
                          "Useful for repairing bottle uploads that previously failed."
      flag   "--bintray-org=",
             description: "Upload to the specified Bintray organisation (default: `homebrew`)."
      flag   "--root-url=",
             description: "Use the specified <URL> as the root of the bottle's URL instead of Homebrew's default."
    end
  end

  def check_bottled_formulae(json_files)
    hashes = json_files.reduce({}) do |hash, json|
      hash.deep_merge(JSON.parse(IO.read(json)))
    end

    hashes.each do |name, hash|
      formula_path = HOMEBREW_REPOSITORY/hash["formula"]["path"]
      formula_version = Formulary.factory(formula_path).pkg_version
      bottle_version = PkgVersion.parse hash["formula"]["pkg_version"]
      next if formula_version == bottle_version

      odie "Bottles are for #{name} #{bottle_version} but formula is version #{formula_version}!"
    end
  end

  def pr_upload
    args = pr_upload_args.parse

    bintray_org = args.bintray_org || "homebrew"
    bintray = Bintray.new(org: bintray_org)

    json_files = Dir["*.json"]
    odie "No JSON files found in the current working directory" if json_files.empty?

    bottle_args = ["bottle", "--merge", "--write"]
    bottle_args << "--verbose" if args.verbose?
    bottle_args << "--debug" if args.debug?
    bottle_args << "--keep-old" if args.keep_old?
    bottle_args << "--root-url=#{args.root_url}" if args.root_url
    bottle_args += json_files

    if args.dry_run?
      puts "brew #{bottle_args.join " "}"
      puts "Upload bottles described by these JSON files to Bintray:\n  #{json_files.join("\n  ")}"
    else
      check_bottled_formulae(json_files)
      safe_system HOMEBREW_BREW_FILE, *bottle_args
      bintray.upload_bottle_json(json_files,
                                 publish_package: !args.no_publish?,
                                 warn_on_error:   args.warn_on_upload_failure?)
    end
  end
end

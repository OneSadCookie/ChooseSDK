#!/usr/bin/ruby

NONSTANDARD_SDKS = {
    '10.3.9' => '10.3',
    '10.4u' => '10.4'
}

def standardize_sdk(sdk_name)
    NONSTANDARD_SDKS[sdk_name] || sdk_name
end

def macosx_to_darwin_version(macosx_version)
    macosx_version =~ /^10\.(\d+)$/
    $1.to_i + 4
end

MINIMUM_DARWIN_VERSION_BY_ARCH = {
    'ppc' => 7,
    'i386' => 8,
    'ppc64' => 9,
    'x86_64' => 9,
}

MAXIMUM_DARWIN_VERSION_BY_ARCH = {
    'ppc' => 9,
    'ppc64' => 9,
}

def current_darwin_version()
    `uname -r` =~ /^(\d+).*$/
    $1.to_i
end

def possible_darwin_versions(arch)
    min = MINIMUM_DARWIN_VERSION_BY_ARCH[arch]
    max = MAXIMUM_DARWIN_VERSION_BY_ARCH[arch] || current_darwin_version()
    min..max
end

def available_sdks()
    Hash[*(Dir[$developer + '/SDKs/*.sdk'].map { |sdk|
        sdk =~ /.*MacOSX(.*)\.sdk/
        sdk_name = $1
        [macosx_to_darwin_version(standardize_sdk(sdk_name)), sdk_name]
    }.flatten)]
end

MIN_OS_VERSION_BY_DARWIN_VERSION = {
    7 => '10.3.9',
}

def min_os_version_from_darwin_version(version)
    MIN_OS_VERSION_BY_DARWIN_VERSION[version] || "10.#{version - 4}"
end

COMPILERS_BY_DARWIN_VERSION = {
    7 => ['gcc-4.0', 'g++-4.0'],
    8 => ['gcc-4.0', 'g++-4.0'],
    9 => ['gcc-4.2', 'g++-4.2'],
   10 => ['gcc-4.2', 'g++-4.2'],
}

def cc_from_darwin_version(version)
    COMPILERS_BY_DARWIN_VERSION[version][0] || 'cc'
end

def cxx_from_darwin_version(version)
    COMPILERS_BY_DARWIN_VERSION[version][1] || 'c++'
end

def choose_sdk(arch)
    sdks = available_sdks()
    versions = possible_darwin_versions(arch)
    versions_with_sdks = versions.find_all { |v| sdks[v] }
    version = versions_with_sdks[0]
    
    {
        'SDK'                => "#{$developer}/SDKs/MacOSX#{sdks[version]}.sdk",
        'MACOSX_VERSION_MIN' => min_os_version_from_darwin_version(version),
        'CC'                 => "#{$developer}/usr/bin/#{cc_from_darwin_version(version)}",
        'CXX'                => "#{$developer}/usr/bin/#{cxx_from_darwin_version(version)}",
    }
end

def main
    $developer = `xcode-select -print-path`.chomp
    if $?.exitstatus != 0 then
        $stderr.puts "Can't run xcode-select -print-path"
        exit
    end

    arch = ARGV[0]
    if !MINIMUM_DARWIN_VERSION_BY_ARCH[arch] then
        $stderr.puts "Unknown architecture: #{arch}"
        exit
    end
    
    env = choose_sdk(arch)
    # TODO getopt_long
    if ARGV.include?('--json') then
        puts '{'
        puts env.map { |k, v| "    \"#{k}\": \"#{v}\""}.join(",\n")
        puts '}'
    elsif ARGV.include?('--print-env') then
        puts env.map { |k, v| "#{k} = #{v}"}.join("\n")
    elsif ARGV.include?('--run') then
        env.each do |k, v|
            ENV[k] = v
        end
        system(ARGV[ARGV.index('--run') + 1])
    end
end

main

require 'mkmf'
require 'open-uri'

workdir = Dir.pwd
pgdir = File.join(workdir, "postgres")

# Download & compile PostgreSQL if we don't have it yet
#
# Note: We intentionally use a patched version that fixes bugs in outfuncs.c
if !Dir.exists?(pgdir)
  unless File.exists?("#{workdir}/postgres.zip")
    File.open("#{workdir}/postgres.zip", "wb") do |target_file|
      open("https://codeload.github.com/pganalyze/postgres/zip/pg_query", "rb") do |read_file|
        target_file.write(read_file.read)
      end
    end
  end
  system("unzip -q #{workdir}/postgres.zip -d #{workdir}") || raise("ERROR")
  system("mv #{workdir}/postgres-pg_query #{pgdir}") || raise("ERROR")
  system("cd #{pgdir}; CFLAGS=-fPIC ./configure") || raise("ERROR")
  system("cd #{pgdir}; make") || raise("ERROR")
end

$objs = `find #{pgdir}/src/backend -name '*.o' | egrep -v '(main/main\.o|snowball|libpqwalreceiver|conversion_procs)' | xargs echo`
$objs += " #{pgdir}/src/timezone/localtime.o #{pgdir}/src/timezone/strftime.o #{pgdir}/src/timezone/pgtz.o"
$objs += " #{pgdir}/src/common/libpgcommon_srv.a #{pgdir}/src/port/libpgport_srv.a"
$objs = $objs.split(" ")

$objs << File.join(File.dirname(__FILE__), "pg_query.o")

$CFLAGS << " -I #{pgdir}/src/include"

SYMFILE = File.join(File.dirname(__FILE__), "pg_query.sym")
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << "-Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << "-Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
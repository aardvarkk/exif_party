#!/usr/bin/env ruby

require 'pry-byebug'
require 'exiftool'
require 'fileutils'
require 'pathname'

# Move files from a source path to a destination root path based on their exif data
def move_files(
  src_files:,
  dst_dir:,
  dry_run: true
)
  # Multiget exif info
  e = Exiftool.new(src_files)

  # puts src_files

  src_files.each do |f|
    exif_info = e.result_for(f).to_hash
    # puts exif_info
    create_date = exif_info[:create_date_civil]
    dst_path = File.join(dst_dir, create_date.year.to_s, create_date.to_s, File.basename(f))
    # puts dst_path

    abort if File.exists?(dst_path)

    puts "Moving #{f} to #{dst_path}"

    next if dry_run

    FileUtils.mkdir_p(File.dirname(dst_path))
    FileUtils.mv(f, dst_path)
  end
end

# Fix dumb issue I created by making extra directories
def fix_dirs(src_dir:, dry_run: true)
  files_and_dirs = Dir[src_dir + "/**/"]
  files_and_dirs.each do |f|
    next unless File.directory?(f)
    next unless f[-5..-2] == '.MP4'

    contained = Dir[f + "*"]
    contained.each do |to_move|
      # FileUtils.mv(to_move, '..')
    end

    next if dry_run
    FileUtils.rmdir(f)
  end
end

# offset_seconds should be the offset between the location these files are being processed and where they were captured
# We want the dates the files are organized in to represent the *local time when the images were taken*
def adjust_dates(
  src_files:,
  target_time:,
  offset_seconds: 0,
  dry_run: true
)
  src_files.sort!

  e = Exiftool.new(src_files)

  created_times = []

  src_files.each do |f|
    exif_info = e.result_for(f).to_hash
    created_times << Time.strptime(exif_info[:create_date], '%Y:%m:%d %H:%M:%S')
  end

  average_time = Time.at(created_times.map(&:to_f).sum/created_times.length)
  adj = target_time.to_f - average_time.to_f

  # puts "Adjusting by #{adj} seconds"

  src_files.each do |f|
    exif_info = e.result_for(f).to_hash
    created_time = Time.strptime(exif_info[:create_date], '%Y:%m:%d %H:%M:%S')
    new_created_time = created_time + adj + offset_seconds
    new_created_timestr = new_created_time.strftime('%Y:%m:%d %H:%M:%S')

    puts "Adjusting #{f} from #{created_time} to #{new_created_timestr}"

    next if dry_run
    `exiftool -overwrite_original -createdate="#{new_created_timestr}" #{f}`
  end
end

# fix_dirs(
#   src_dir: '/Users/aardvarkk/Pictures'
# )

# adjust_dates(
#   src_files: Dir['/Users/aardvarkk/Pictures/2015/2015-01-01/*.MP4'],
#   target_time: Time.parse('2016-12-25T12:00-05'),
#   offset_seconds: 3 * 3600
# )

# adjust_dates(
#   src_files: Dir['/Users/aardvarkk/Pictures/2018/2018-12-31/*.{JPG,MP4}'],
#   target_time: Time.parse('2019-01-01T14:50-08'),
#   offset_seconds: 3 * 3600,
#   dry_run: false
# )

move_files(
  src_files: Dir['/Users/aardvarkk/Pictures/2018/2018-12-31/**/*.{JPG,MP4}'],
  dst_dir: '/Users/aardvarkk/Pictures',
  # dry_run: false
)


if ARGV
	slug = ARGV[0]
else
	slug = ""
end

Dir.glob("#{slug}*_test.rb").each do |file|
	require "./#{file}"
end
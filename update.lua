src = 'http://home.vectorjohn.com/omgturtles'
dir = '/john'

fs.makeDir( dir )

print( 'loading index file...' )
index = http.get( src .. '/index.txt' )
if not index then
	print( "something went wrong getting index" )
	exit()
end

f = fs.open( dir..'/index.txt', 'w' )
f.write( index.readAll() )

f.close()

index = fs.open( dir..'/index.txt', 'r' )

filename = index.readLine()
while filename do
	if string.sub( filename, string.len( filename ) ) == '/' then
		print( 'creating directory ', filename )
		fs.makeDir( dir..'/'..filename )
	else
		print( 'getting ', filename )
		data = http.get( src..'/'..filename )
		if not data then
			print( 'Error loading file: ', filename )
		else
			f = fs.open( dir..'/'..filename, 'w' )
			f.write( data.readAll() )
			f.close()
		end
	end
	
	filename = index.readLine()
end

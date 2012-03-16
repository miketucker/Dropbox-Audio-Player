require 'rubygems'
require 'sinatra'
require 'pp'
require 'dropbox_sdk'
require 'json'
require 'open-uri'
require 'stringio'
require 'net/http'
require 'net/https'
require 'uri'
require 'mp3info'

set :public_folder, 'brunch/build'

APP_KEY = 'XXXXX'
APP_SECRET = 'XXXXX'
ACCESS_TYPE = :app_folder
						
						
						

# --------------------------------------------------------------------------------------------------------------------------------------
# OAuth stuff

get '/oauth-start' do
	# OAuth Step 1: Get a request token from Dropbox.
	db_session = DropboxSession.new(APP_KEY, APP_SECRET)
	begin
		db_session.get_request_token
	rescue DropboxError => e
		return html_page "Exception in OAuth step 1", "<p>#{h e}</p>"
	end

	session[:request_db_session] = db_session.serialize

	# OAuth Step 2: Send the user to the Dropbox website so they can authorize
	# our app.  After the user authorizes our app, Dropbox will redirect them
	# to our '/oauth-callback' endpoint.
	auth_url = db_session.get_authorize_url url('/oauth-callback')
	redirect auth_url 
end

# --------------------------------------------------------------------------------------------------------------------------------------

get '/oauth-callback' do
	# Finish OAuth Step 2
	ser = session[:request_db_session]
	unless ser
		return html_page "Error in OAuth step 2", "<p>Couldn't find OAuth state in session.</p>"
	end
	db_session = DropboxSession.deserialize(ser)

	# OAuth Step 3: Get an access token from Dropbox.
	begin
		db_session.get_access_token
	rescue DropboxError => e
		return html_page "Exception in OAuth step 3", "<p>#{h e}</p>"
	end
	session.delete(:request_db_session)
	session[:authorized_db_session] = db_session.serialize
	redirect url('/')
	# In this simple example, we store the authorized DropboxSession in the web
	# session hash.  A "real" webapp might store it somewhere more persistent.
end

# --------------------------------------------------------------------------------------------------------------------------------------

# If we already have an authorized DropboxSession, returns a DropboxClient.
def get_db_client
	if session[:authorized_db_session]
		db_session = DropboxSession.deserialize(session[:authorized_db_session])
		begin
			return DropboxClient.new(db_session, ACCESS_TYPE)
		rescue DropboxAuthError => e
			# The stored session didn't work.  Fall through and start OAuth.
			session[:authorized_db_session].delete
		end
	end
end

# --------------------------------------------------------------------------------------------------------------------------------------
# File/folder display stuff

get '/path/' do

	db_client = get_db_client
	unless db_client
		redirect url("/oauth-start")
	end
	# Call DropboxClient.metadata
	path = params[:path] || '/'
	begin
		entry = db_client.metadata(path)
	rescue DropboxAuthError => e
		session.delete(:authorized_db_session)  # An auth error means the db_session is probably bad
		return html_page "Dropbox auth error", "<p>#{h e}</p>"
	rescue DropboxError => e
		if e.http_response.code == '404'
			return html_page "Path not found: #{h path}", ""
		else
			return html_page "Dropbox API error", "<pre>#{h e.http_response}</pre>"
		end
	end

	if entry['is_dir']
		render_folder(db_client, entry)
	else
		render_file(db_client, entry)
	end

end

# --------------------------------------------------------------------------------------------------------------------------------------
# Returns a temporary URL to access the file along with an expiration date (2hrs after u got it)

get '/url/:path' do
	db_client = get_db_client
	unless db_client
		redirect url("/oauth-start")
	end

	JSON.generate(db_client.media(params[:path]))
end

# --------------------------------------------------------------------------------------------------------------------------------------
# Do oauth then redirect to index

get '/' do
	# Get the DropboxClient object.  Redirect to OAuth flow if necessary.
	db_client = get_db_client
	unless db_client
		redirect url("/oauth-start")
	end

	File.open('brunch/build/index.html')
end

# get JSON of files from current dir
# TODO: Support directories

get '/json' do
	# Get the DropboxClient object.  Redirect to OAuth flow if necessary.
	db_client = get_db_client
	unless db_client
		redirect url("/oauth-start")
	end

	path = '/' #params[:path] || '/json'
	begin
		entry = db_client.metadata(path)
	rescue DropboxAuthError => e
		session.delete(:authorized_db_session)  # An auth error means the db_session is probably bad
		return html_page "Dropbox auth error", "<p>#{h e}</p>"
	rescue DropboxError => e
		if e.http_response.code == '404'
			return html_page "Path not found: #{h path}", ""
		else
			return html_page "Dropbox API error", "<pre>#{h e.http_response}</pre>"
		end
	end

	return do_json(db_client,entry)

end


# --------------------------------------------------------------------------------------------------------------------------------------
# pick out the files that are actually MP3S
# TODO: support other audio types?
# TODO: metadata from mp3s

class Net::HTTPResponse
  attr_reader :socket
end

def do_json (db_client,entry)

	ar = []
i = 0
	entry['contents'].each do |child|
		if child['mime_type'] == "audio/mpeg" || child['mime_type'] == "audio/ogg"
			child['mp3'] = db_client.media(child['path'])['url']

			url = URI.parse child['mp3']
			http = Net::HTTP.new(url.host, url.port)
			http.use_ssl = (url.scheme == 'https')

			req = Net::HTTP::Get.new(url.path)
			req.range = (0..4024)

			res = http.request(req)
			

			Mp3Info.open( StringIO.open(res.body) ) do |m|
				t = child['path'][1..-1].split('.')

				child['title'] = m.tag.title ? m.tag.title : t[0..(t.count-2)].join(' ') 
				child['album'] = m.tag.album ? m.tag.album : "Unknown Album" 
				child['artist'] = m.tag.artist ? m.tag.artist : "Unknown Artist" 
				child['length'] = m.length > 0 ? m.length : "?:??"
			end
			# FORMAT title 
			ar.push child
			i += 1
		end
	end

	JSON.generate(ar)
end


# --------------------------------------------------------------------------------------------------------------------------------------

def upload_form(entry)
	out = "<form action='/upload' method='post' enctype='multipart/form-data'>"
	out += "<label for='file'>Upload file:</label> <input name='file' type='file'/>"
	out += "<input type='submit' value='Upload'/>"
	out += "<input name='folder' type='hidden' value='#{h entry['path']}'/>"
	out += "</form>"  # TODO: Add a token to counter CSRF attacks.
end

# --------------------------------------------------------------------------------------------------------------------------------------

def render_upload(db_client,entry)
	html_page "Upload", upload_form(entry)
end

# --------------------------------------------------------------------------------------------------------------------------------------

def render_folder(db_client, entry)
	# Provide an upload form (so the user can add files to this folder)
	out = upload_form(entry)
	# List of folder contents
	entry['contents'].each do |child|
		cp = child['path']      # child path
		cn = File.basename(cp)  # child name
		if (child['is_dir']) then cn += '/' end
		out += child.pretty_inspect
		out += "<div><a style='text-decoration: none' href='/?path=#{h cp}'>#{h cn}</a></div>"
	end

	html_page "Folder: #{entry['path']}", out
end

# --------------------------------------------------------------------------------------------------------------------------------------

def render_file(db_client, entry)
	# Just dump out metadata hash
	html_page "File: #{entry['path']}", "<pre>#{h entry.pretty_inspect}</pre>"
end

# -------------------------------------------------------------------
# File upload handler

post '/upload' do
	# Check POST parameter.
	file = params[:file]
	unless file && (temp_file = file[:tempfile]) && (name = file[:filename])
		return html_page "Upload error", "<p>No file selected.</p>"
	end

	# Get the DropboxClient object.
	db_client = get_db_client
	unless db_client
		return html_page "Upload error", "<p>Not linked with a Dropbox account.</p>"
	end

	# Call DropboxClient.put_file
	begin
		entry = db_client.put_file("#{params[:folder]}/#{name}", temp_file.read)
	rescue DropboxAuthError => e
		session.delete(:authorized_db_session)  # An auth error means the db_session is probably bad
		return html_page "Dropbox auth error", "<p>#{h e}</p>"
	rescue DropboxError => e
		return html_page "Dropbox API error", "<p>#{h e}</p>"
	end

	html_page "Upload complete", "<pre>#{h entry.pretty_inspect}</pre>"
end

# -------------------------------------------------------------------

def html_page(title, body)
	"<html>" +
		"<head><title>#{h title}</title></head>" +
		"<body><h1>#{h title}</h1>#{body}</body>" +
	"</html>"
end

enable :sessions

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end

if APP_KEY == '' or APP_SECRET == ''
	puts "You must set APP_KEY and APP_SECRET at the top of \"#{__FILE__}\"!"
	exit 1
end

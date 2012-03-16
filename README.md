# Dropbox Audio Player

A minimal tool to play audio from your dropbox account.

Use the live service at [soundstash.heroku.com](http://soundstash.heroku.com) or fork your own.


### Libraries

- [Brunch](http://brunch.io): a backbone.js, Coffeescript, ECO mashup for the frontend
- [Sinatra](http://sinatrarb.com): A lightweight ruby backend for use with the Dropbox Ruby SDK
- [CodeBase Hero's HTML5 Music Player](http://www.codebasehero.com/2011/07/html5-music-player-updated/): The HTML5 audio player

### Current functionality

- Loads all MP3s from the app's dropbox folder
- Plays through each in order of ascending name

### Todo

- Reorder, modify playlist
- Read subdirectories
- OGG support
- Sort by artist, title

## Installation

* Install [Sinatra](http://sinatrarb.com)
* Install [Brunch](http://brunch.io)
* Register an app at [dropbox.com/developers/apps](https://www.dropbox.com/developers/apps)
* Add your App key and secret to `index.rb`
* Install the gems listed in `Gemfile`
* In terminal, run `ruby index.rb`
* That's it! You should be running locally
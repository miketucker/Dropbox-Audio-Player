class exports.Song extends Backbone.Model
	defaults:
		artist: "Artist Name"
		cover: "images/1.png"
		ogg: 'mix/1.ogg'
		title: "Song title"
		duration: "4:28"
		buy:'#'
		rating: 4
		price: '0.99'

	get_url: (callback) ->
		$.getJSON "/url"+@get('path'), (data) ->
			callback(data)
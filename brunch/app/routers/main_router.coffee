class exports.MainRouter extends Backbone.Router
	routes :
		'': 'home'

	home: ->

		if(app.songs.length > 0)	
			$('body').html ""	
			$('body').ttwMusicPlayer app.songs.toJSON(),
				autoPlay:true
				errorAlerts: true
				warningAlerts: true
				jPlayer:
					swfPath:'scripts/'
		else
			$('body').html require 'views/templates/instructions'
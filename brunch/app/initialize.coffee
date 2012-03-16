{BrunchApplication} = require 'helpers'
{MainRouter} = require 'routers/main_router'
{HomeView} = require 'views/home_view'
{Songs} = require 'collections/songs'

class exports.Application extends BrunchApplication
	initialize: ->
		@loader()
		$.getJSON '/json', (data) =>
			@spinner.stop()
			@songs = new Songs(data)
			@homeView = new HomeView
			@router = new MainRouter
			Backbone.history.start()

	loader: ->
		opts = 
			lines: 8 # The number of lines to draw
			length: 0 # The length of each line
			width: 4 # The line thickness
			radius: 6 # The radius of the inner circle
			color: '#fff' # #rgb or #rrggbb
			speed: 1 # Rounds per second
			trail: 60 # Afterglow percentage
			shadow: false # Whether to render a shadow
			hwaccel: false # Whether to use hardware acceleration
			className: 'spinner' # The CSS class to assign to the spinner
			zIndex: 200 # The z-index (defaults to 2000000000)
			top: 'auto' # Top position relative to parent in px
			left: 'auto' # Left position relative to parent in px

		@spinner = new Spinner(opts).spin()
		$('body').html require 'views/templates/loading'
		div = $('body').find('#spinContainer')[0]
		$(div).html @spinner.el

window.app = new exports.Application





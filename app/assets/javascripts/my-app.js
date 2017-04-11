var ready = function(){
	// Initialize your app
	var myApp = new Framework7({
		swipeBackPage: false,
	});

	// Export selectors engine
	var $$ = Dom7;
	// Add view
	var mainView = myApp.addView('.view-main');

	$(".swipebox").swipebox();
}
$(document).on('turbolinks:load', ready);


var Config,SDApi;

Config = require('../conf');




SDApi = (function (){
	function SDApi(){
		//console.log('ggggggggg');
		//var GET_CONTACT_BY_E_URL = 'aadfsdfdfds';
	}
		


	//SDApi.sd_api = process.env.NODE_ENV === 'development'  ? Config.SD_API_TEST : Config.SD_API ;
	var GET_CONTACT_BY_E_URL = 'aadfsdfdfds';
	console.log('aaaa'+SDApi.sd_api);
	return SDApi;
});

module.exports = SDApi;
var Config, LRU, Session, Utility, co, process;

process = require('process');

LRU = require("lru-cache");

co = require('co');

Config = require('../conf');

Utility = require('./util').Utility;

Session = (function() {
  function Session() {}

  Session.cache = LRU({
    max: 5000,
    maxAge: 1000 * 60 * 60
  });

  Session.getCurrentUserId = function(req) {
    var cookie;
    cookie = req.cookies[Config.AUTH_COOKIE_NAME];
    if (!cookie) {
      return null;
    }
    return parseInt(Utility.decryptText(cookie, Config.AUTH_COOKIE_KEY));
  };

  Session.getCurrentUserNickname = function(userId, UserModel) {
    var cache, cachedNickname;
    cachedNickname = this.cache.get('nickname_' + userId);
    cache = this.cache;
    return new Promise(function(resolve, reject) {
      if (cachedNickname) {
        return resolve(cachedNickname);
      }
      return UserModel.getNickname(userId).then(function(nickname) {
        if (nickname) {
          cache.set('nickname_' + userId, nickname);
        }
        return resolve(nickname);
      })["catch"](function(err) {
        return reject(err);
      });
    });
  };

  Session.setNicknameToCache = function(userId, nickname) {
    if (!Number.isInteger(userId) || Utility.isEmpty(nickname)) {
      throw new Error('Invalid userId or nickname.');
    }
    return this.cache.set('nickname_' + userId, nickname);
  };

  Session.setAuthCookie = function(res, userId) {
    var value;
    value = Utility.encryptText(userId, Config.AUTH_COOKIE_KEY);
    return res.cookie(Config.AUTH_COOKIE_NAME, value, {
      httpOnly: true,
      maxAge: Config.AUTH_COOKIE_MAX_AGE,
      expires: new Date(Date.now() + Config.AUTH_COOKIE_MAX_AGE)
    });
  };

  return Session;

})();

module.exports = Session;

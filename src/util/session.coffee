process = require 'process'
LRU     = require "lru-cache"
co      = require 'co'
Config  = require '../conf'
Utility = require('./util').Utility

class Session
  @cache = LRU
    max: 5000
    maxAge: 1000 * 60 * 60

  @getCurrentUserId: (req) ->
    # 开发环境可以通过 URL 参数 ?userId=123 或者 encodeUserId=X8dmd7d 设置当前登录的 userId
    # if process.env.NODE_ENV is 'development'
    #   if req.query.userId
    #     return req.query.userId
    #   else if req.query.encodeUserId
    #     return Utility.decodeIds req.query.encodeUserId

    cookie = req.cookies[Config.AUTH_COOKIE_NAME]

    return null if not cookie

    parseInt Utility.decryptText cookie, Config.AUTH_COOKIE_KEY

  @getCurrentUserNickname: (userId, UserModel) ->
    cachedNickname = @cache.get 'nickname_' + userId

    cache = @cache

    new Promise (resolve, reject) ->
      if cachedNickname
        return resolve cachedNickname

      UserModel.getNickname userId
      .then (nickname) ->
        if nickname
          cache.set 'nickname_' + userId, nickname

        resolve nickname
      .catch (err) ->
        reject err

  @setNicknameToCache: (userId, nickname) ->
    if not Number.isInteger(userId) or Utility.isEmpty nickname
      throw new Error 'Invalid userId or nickname.'

    @cache.set 'nickname_' + userId, nickname


  @setAuthCookie: (res, userId) ->
    value = Utility.encryptText userId, Config.AUTH_COOKIE_KEY

    res.cookie Config.AUTH_COOKIE_NAME, value,
      #secure: true
      httpOnly: true
      maxAge: Config.AUTH_COOKIE_MAX_AGE
      expires: new Date(Date.now() + Config.AUTH_COOKIE_MAX_AGE)

module.exports = Session

request = require 'supertest'
cookie  = require 'cookie'
_       = require 'underscore'
app     = require '../../src'
config  = require '../../src/conf'
Utility = require('../../src/util/util').Utility

# 引用数据库对象和模型
[sequelize, User] = require '../../src/db'

beforeAll ->

  this.phoneNumber1 = '13' + Math.floor(Math.random() * 99999999 + 900000000)
  this.phoneNumber2 = '13' + Math.floor(Math.random() * 99999999 + 900000000)
  this.phoneNumber3 = '13' + Math.floor(Math.random() * 99999999 + 900000000)

  #this.username1 = 'arielyang'
  #this.username2 = 'novasman'
  #this.username3 = 'luckyjiang'

  this.nickname1 = 'Ariel Yang'
  this.nickname2 = 'Novas Man'
  this.nickname3 = 'Lucky Jiang'

  this.userId1 = null
  this.userId2 = null
  this.userId3 = null

  this.password = 'P@ssw0rd'
  this.passwordNew = 'P@ssw0rdNew'

  this.groupName1 = 'Business'
  this.groupName2 = 'Product'

  this.groupId1 = null
  this.groupId2 = null

  this.userCookie1 = null
  this.userCookie2 = null
  this.userCookie3 = null

  this.xssString = '<a>hello</a>'
  this.filteredString = '&lt;a&gt;hello&lt;/a&gt;'

  getAuthCookieValue = (res) ->
    cookieHeader = res.header['set-cookie']

    if cookieHeader
      if Array.isArray cookieHeader
        cookieHeader = cookieHeader[0]

      return authCookieValue = cookie.parse(cookieHeader)[config.AUTH_COOKIE_NAME]

    return null

  this.testPOSTAPI = (path, cookieValue, params, statusCode, testBody, callback) ->
    _this = this

    if arguments.length is 5
      callback = testBody
      testBody = statusCode
      statusCode = params
      params = cookieValue
      cookieValue = ''

    setTimeout ->
      request app
        .post path
        .set 'Cookie', config.AUTH_COOKIE_NAME + '=' + cookieValue
        .type 'json'
        .send params
        .end (err, res) ->
          _this.testHTTPResult err, res, statusCode, testBody

          callback res.body, getAuthCookieValue(res) if callback
    , 10

  this.testGETAPI = (path, cookieValue, statusCode, testBody, callback) ->
    _this = this

    if arguments.length is 4
      callback = testBody
      testBody = statusCode
      statusCode = cookieValue
      cookieValue = ''

    setTimeout ->
      request app
        .get path
        .set 'Cookie', config.AUTH_COOKIE_NAME + '=' + cookieValue
        .end (err, res) ->
          _this.testHTTPResult err, res, statusCode, testBody
          callback res.body if callback
    , 10

  this.testHTTPResult = (err, res, statusCode, testBody) ->
    cacheControl = res.get 'Cache-Control'
    contentType = res.get 'Content-Type'

    switch res.status
      when 200
        expect(contentType).toEqual('application/json; charset=utf-8')
        expect(cacheControl).toEqual('private')
      when 204
        expect(contentType).toEqual(undefined)
      else
        expect(contentType).toEqual('text/html; charset=utf-8')

    if statusCode
      expect(res.status).toEqual(statusCode)

      if res.status is 500
        console.log 'Server error: ', res.text
        console.log 'Respone status: ', res.status
        console.log 'Respone error: ', err

        return
      else if res.status isnt statusCode
        console.log 'Respone message: ', res.text
        console.log 'Respone status: ', res.status
        console.log 'Respone error: ', err

        return

    testProperty = (obj, testBody) ->
      for p of testBody
        if typeof testBody[p] is 'object'
          testProperty obj[p], testBody[p]
        else
          switch testBody[p]
            when 'INTEGER'
              expect(Number.isInteger obj[p]).toBeTruthy()
            when 'UUID'
              expect(obj[p]).toMatch(/[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/)
            when 'STRING'
              expect(typeof obj[p] is 'string').toBeTruthy()
            when 'NULL'
              expect(obj[p]).toBeNull()
            else
              expect(testBody[p]).toEqual(obj[p])

    testProperty res.body, testBody

  this.createUser = (user, callback) ->
    passwordSalt = _.random 1000, 9999
    passwordHash = Utility.hash user.password, passwordSalt

    User.create
      #username: user.username
      region: user.region
      phone: user.phone
      nickname: user.nickname
      passwordHash: passwordHash
      passwordSalt: passwordSalt.toString()
    .then (user) ->
      callback Utility.encodeId user.id
    .catch (err) ->
      console.log 'Create user failed: ', err

  this.loginUser = (phoneNumber, callback) ->
    request app
      .post '/user/login'
      .type 'json'
      .send
        region: '86'
        phone: phoneNumber
        password: this.password
      .end (err, res) ->
        if not err and res.status is 200
          callback res.body.result.id, getAuthCookieValue(res)
        else
          console.log 'Login user failed: ', err

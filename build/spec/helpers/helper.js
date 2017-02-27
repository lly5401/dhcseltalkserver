var User, Utility, _, app, config, cookie, ref, request, sequelize;

request = require('supertest');

cookie = require('cookie');

_ = require('underscore');

app = require('../../src');

config = require('../../src/conf');

Utility = require('../../src/util/util').Utility;

ref = require('../../src/db'), sequelize = ref[0], User = ref[1];

beforeAll(function() {
  var getAuthCookieValue;
  this.phoneNumber1 = '13' + Math.floor(Math.random() * 99999999 + 900000000);
  this.phoneNumber2 = '13' + Math.floor(Math.random() * 99999999 + 900000000);
  this.phoneNumber3 = '13' + Math.floor(Math.random() * 99999999 + 900000000);
  this.nickname1 = 'Ariel Yang';
  this.nickname2 = 'Novas Man';
  this.nickname3 = 'Lucky Jiang';
  this.userId1 = null;
  this.userId2 = null;
  this.userId3 = null;
  this.password = 'P@ssw0rd';
  this.passwordNew = 'P@ssw0rdNew';
  this.groupName1 = 'Business';
  this.groupName2 = 'Product';
  this.groupId1 = null;
  this.groupId2 = null;
  this.userCookie1 = null;
  this.userCookie2 = null;
  this.userCookie3 = null;
  this.xssString = '<a>hello</a>';
  this.filteredString = '&lt;a&gt;hello&lt;/a&gt;';
  getAuthCookieValue = function(res) {
    var authCookieValue, cookieHeader;
    cookieHeader = res.header['set-cookie'];
    if (cookieHeader) {
      if (Array.isArray(cookieHeader)) {
        cookieHeader = cookieHeader[0];
      }
      return authCookieValue = cookie.parse(cookieHeader)[config.AUTH_COOKIE_NAME];
    }
    return null;
  };
  this.testPOSTAPI = function(path, cookieValue, params, statusCode, testBody, callback) {
    var _this;
    _this = this;
    if (arguments.length === 5) {
      callback = testBody;
      testBody = statusCode;
      statusCode = params;
      params = cookieValue;
      cookieValue = '';
    }
    return setTimeout(function() {
      return request(app).post(path).set('Cookie', config.AUTH_COOKIE_NAME + '=' + cookieValue).type('json').send(params).end(function(err, res) {
        _this.testHTTPResult(err, res, statusCode, testBody);
        if (callback) {
          return callback(res.body, getAuthCookieValue(res));
        }
      });
    }, 10);
  };
  this.testGETAPI = function(path, cookieValue, statusCode, testBody, callback) {
    var _this;
    _this = this;
    if (arguments.length === 4) {
      callback = testBody;
      testBody = statusCode;
      statusCode = cookieValue;
      cookieValue = '';
    }
    return setTimeout(function() {
      return request(app).get(path).set('Cookie', config.AUTH_COOKIE_NAME + '=' + cookieValue).end(function(err, res) {
        _this.testHTTPResult(err, res, statusCode, testBody);
        if (callback) {
          return callback(res.body);
        }
      });
    }, 10);
  };
  this.testHTTPResult = function(err, res, statusCode, testBody) {
    var cacheControl, contentType, testProperty;
    cacheControl = res.get('Cache-Control');
    contentType = res.get('Content-Type');
    switch (res.status) {
      case 200:
        expect(contentType).toEqual('application/json; charset=utf-8');
        expect(cacheControl).toEqual('private');
        break;
      case 204:
        expect(contentType).toEqual(void 0);
        break;
      default:
        expect(contentType).toEqual('text/html; charset=utf-8');
    }
    if (statusCode) {
      expect(res.status).toEqual(statusCode);
      if (res.status === 500) {
        console.log('Server error: ', res.text);
        console.log('Respone status: ', res.status);
        console.log('Respone error: ', err);
        return;
      } else if (res.status !== statusCode) {
        console.log('Respone message: ', res.text);
        console.log('Respone status: ', res.status);
        console.log('Respone error: ', err);
        return;
      }
    }
    testProperty = function(obj, testBody) {
      var p, results;
      results = [];
      for (p in testBody) {
        if (typeof testBody[p] === 'object') {
          results.push(testProperty(obj[p], testBody[p]));
        } else {
          switch (testBody[p]) {
            case 'INTEGER':
              results.push(expect(Number.isInteger(obj[p])).toBeTruthy());
              break;
            case 'UUID':
              results.push(expect(obj[p]).toMatch(/[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/));
              break;
            case 'STRING':
              results.push(expect(typeof obj[p] === 'string').toBeTruthy());
              break;
            case 'NULL':
              results.push(expect(obj[p]).toBeNull());
              break;
            default:
              results.push(expect(testBody[p]).toEqual(obj[p]));
          }
        }
      }
      return results;
    };
    return testProperty(res.body, testBody);
  };
  this.createUser = function(user, callback) {
    var passwordHash, passwordSalt;
    passwordSalt = _.random(1000, 9999);
    passwordHash = Utility.hash(user.password, passwordSalt);
    return User.create({
      region: user.region,
      phone: user.phone,
      nickname: user.nickname,
      passwordHash: passwordHash,
      passwordSalt: passwordSalt.toString()
    }).then(function(user) {
      return callback(Utility.encodeId(user.id));
    })["catch"](function(err) {
      return console.log('Create user failed: ', err);
    });
  };
  return this.loginUser = function(phoneNumber, callback) {
    return request(app).post('/user/login').type('json').send({
      region: '86',
      phone: phoneNumber,
      password: this.password
    }).end(function(err, res) {
      if (!err && res.status === 200) {
        return callback(res.body.result.id, getAuthCookieValue(res));
      } else {
        return console.log('Login user failed: ', err);
      }
    });
  };
});

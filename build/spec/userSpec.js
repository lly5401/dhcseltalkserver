describe('用户接口测试', function() {
  var _global, verificationCodeToken;
  _global = null;
  verificationCodeToken = null;
  beforeAll(function() {
    return _global = this;
  });
  afterAll(function(done) {
    return _global.createUser({
      region: '86',
      phone: _global.phoneNumber3,
      nickname: _global.nickname3,
      password: _global.password
    }, function(userId) {
      _global.userId3 = userId;
      return done();
    });
  });
  describe('获取短信图验', function() {
    return xit('成功', function(done) {
      return this.testGETAPI('/user/get_sms_img_code', 200, {
        code: 200,
        result: {
          url: 'STRING',
          verifyId: 'STRING'
        }
      }, done);
    });
  });
  describe('发送验证码', function() {
    it('成功', function(done) {
      return this.testPOSTAPI('/user/send_code', {
        region: '86',
        phone: _global.phoneNumber1
      }, 200, {
        code: 200
      }, done);
    });
    it('区域号为空', function(done) {
      return this.testPOSTAPI('/user/send_code', {
        region: '',
        phone: _global.phoneNumber1
      }, 400, null, done);
    });
    it('手机号为空', function(done) {
      return this.testPOSTAPI('/user/send_code', {
        region: '86',
        phone: ''
      }, 400, null, done);
    });
    it('手机号不合法-20012341234', function(done) {
      return this.testPOSTAPI('/user/send_code', {
        region: '86',
        phone: '20012341234'
      }, 400, null, done);
    });
    it('手机号不合法-130qwerasdf', function(done) {
      return this.testPOSTAPI('/user/send_code', {
        region: '86',
        phone: '130qwerasdf'
      }, 400, null, done);
    });
    return it('超过频率限制', function(done) {
      return this.testPOSTAPI('/user/send_code', {
        region: '86',
        phone: _global.phoneNumber1
      }, 200, {
        code: 5000
      }, done);
    });
  });
  describe('验证验证码', function() {
    xit('正确', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '86',
        phone: this.phoneNumber1,
        code: code
      }, 200, {
        code: 200,
        result: {
          verification_token: 'UUID'
        }
      }, function(body) {
        verificationCodeToken = body.result.verification_token;
        return done();
      });
    });
    it('测试环境万能验证码', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '86',
        phone: this.phoneNumber1,
        code: '9999'
      }, 200, {
        code: 200,
        result: {
          verification_token: 'UUID'
        }
      }, function(body) {
        verificationCodeToken = body.result.verification_token;
        return done();
      });
    });
    it('错误', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '86',
        phone: this.phoneNumber1,
        code: '1234'
      }, 200, {
        code: 1000
      }, done);
    });
    it('验证码为空', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '86',
        phone: '10000000000',
        code: ''
      }, 400, null, done);
    });
    xit('过期', function(done) {
      return _global.getVerificationCode('86', _global.phoneNumber1, function(code) {
        return _global.testPOSTAPI('/user/verify_code', {
          region: '86',
          phone: _global.phoneNumber1,
          code: code
        }, 200, {
          code: 2000
        }, done);
      });
    });
    it('区域号为空', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '',
        phone: _global.phoneNumber1,
        code: '0000'
      }, 400, null, done);
    });
    it('手机号为空', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '86',
        phone: '',
        code: '0000'
      }, 400, null, done);
    });
    return it('手机号不存在', function(done) {
      return this.testPOSTAPI('/user/verify_code', {
        region: '86',
        phone: '10000000000',
        code: '0000'
      }, 404, null, done);
    });
  });
  describe('用户注册', function() {
    it('成功', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.xssString,
        password: _global.password,
        verification_token: verificationCodeToken
      }, 200, {
        code: 200,
        result: {
          id: 'STRING'
        }
      }, function(body, cookie) {
        _global.userId1 = body.result.id;
        _global.userCookie1 = cookie;
        return _global.testGETAPI("/user/" + _global.userId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            nickname: _global.filteredString
          }
        }, done);
      });
    });
    it('手机号已经存在', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: _global.password,
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('昵称为空', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: '',
        password: _global.password,
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('昵称长度大于上限', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: 'a'.repeat(33),
        password: _global.password,
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('密码为空', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: '',
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('密码不能包含空格', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: 'qwe qwe',
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('密码长度小于下限', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: 'a'.repeat(5),
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('密码长度大于上限', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: 'a'.repeat(21),
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('Token 为空', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: _global.password,
        verification_token: ''
      }, 400, null, done);
    });
    it('Token 格式错误', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: _global.password,
        verification_token: '...'
      }, 400, null, done);
    });
    return it('Token 不存在', function(done) {
      return this.testPOSTAPI('/user/register', {
        nickname: _global.nickname1,
        password: _global.password,
        verification_token: '9a615598-7caa-11e5-a305-525439e49ee9'
      }, 404, null, done);
    });
  });
  describe('检查手机号', function() {
    it('存在', function(done) {
      return this.testPOSTAPI('/user/check_phone_available', {
        region: '86',
        phone: _global.phoneNumber1
      }, 200, {
        code: 200,
        result: false
      }, done);
    });
    it('不存在', function(done) {
      return this.testPOSTAPI('/user/check_phone_available', {
        region: '86',
        phone: '13910000000'
      }, 200, {
        code: 200,
        result: true
      }, done);
    });
    it('区域号为空', function(done) {
      return this.testPOSTAPI('/user/check_phone_available', {
        region: '',
        phone: _global.phoneNumber1
      }, 400, null, done);
    });
    it('手机号为空', function(done) {
      return this.testPOSTAPI('/user/check_phone_available', {
        region: '86',
        phone: ''
      }, 400, null, done);
    });
    it('手机号非法-23412341234', function(done) {
      return this.testPOSTAPI('/user/check_phone_available', {
        region: '86',
        phone: '23412341234'
      }, 400, null, done);
    });
    return it('手机号非法-130qwerasdf', function(done) {
      return this.testPOSTAPI('/user/check_phone_available', {
        region: '86',
        phone: '130qwerasdf'
      }, 400, null, done);
    });
  });
  describe('登录', function() {
    it('成功', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: _global.phoneNumber1,
        password: _global.password
      }, 200, {
        code: 200,
        result: {
          token: 'STRING'
        }
      }, function(body, cookie) {
        _global.userCookie1 = cookie;
        expect(cookie).not.toBeNull();
        expect(body.result.id).toEqual(_global.userId1);
        return done();
      });
    });
    it('密码错误', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: _global.phoneNumber1,
        password: _global.password + '1'
      }, 200, {
        code: 1000
      }, done);
    });
    it('手机号不存在', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: '13' + Math.floor(Math.random() * 99999999 + 900000000),
        password: _global.password
      }, 200, {
        code: 1000
      }, done);
    });
    it('区域号为空', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '',
        phone: _global.phoneNumber1,
        password: _global.password
      }, 400, null, done);
    });
    it('手机号为空', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: '',
        password: _global.password
      }, 400, null, done);
    });
    it('密码为空', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: _global.phoneNumber1,
        password: ''
      }, 400, null, done);
    });
    it('手机号不合法-20012341234', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: '20012341234',
        password: _global.password
      }, 400, null, done);
    });
    return it('手机号不合法-130qwerasdf', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: '130qwerasdf',
        password: _global.password
      }, 400, null, done);
    });
  });
  xdescribe('获取融云 Token', function() {
    return it('成功', function(done) {
      return this.testGETAPI("/user/get_token", _global.userCookie1, 200, {
        code: 200,
        result: {
          userId: 'STRING',
          token: 'STRING'
        }
      }, done);
    });
  });
  describe('获取用户基本信息', function() {
    beforeAll(function(done) {
      return this.createUser({
        region: '86',
        phone: _global.phoneNumber2,
        nickname: _global.nickname2,
        password: _global.password
      }, function(userId) {
        _global.userId2 = userId;
        return done();
      });
    });
    it('成功', function(done) {
      return this.testGETAPI("/user/" + _global.userId2, _global.userCookie1, 200, {
        code: 200,
        result: {
          id: 'STRING',
          nickname: 'STRING',
          portraitUri: 'STRING'
        }
      }, done);
    });
    return it('用户 Id 不存在', function(done) {
      return this.testGETAPI("/user/5Vg2XCh9f", _global.userCookie1, 404, null, done);
    });
  });
  describe('批量获取用户基本信息', function() {
    it('成功，数组', function(done) {
      return this.testGETAPI("/user/batch?id=" + _global.userId1 + "&id=" + _global.userId2, _global.userCookie1, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(2);
        if (body.result.length > 0) {
          expect(body.result[0].id).toBeDefined();
          expect(body.result[0].nickname).toBeDefined();
          expect(body.result[0].portraitUri).toBeDefined();
          expect(body.result[1].id).toBeDefined();
          expect(body.result[1].nickname).toBeDefined();
          expect(body.result[1].portraitUri).toBeDefined();
        }
        return done();
      });
    });
    it('成功，单一元素', function(done) {
      return this.testGETAPI("/user/batch?id=" + _global.userId1, _global.userCookie1, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(1);
        if (body.result.length > 0) {
          expect(body.result[0].id).toBeDefined();
          expect(body.result[0].nickname).toBeDefined();
          expect(body.result[0].portraitUri).toBeDefined();
        }
        return done();
      });
    });
    return it('UserId 不存在', function(done) {
      return this.testGETAPI("/user/batch?id=" + _global.userId1 + "&id=5Vg2XCh9f", _global.userCookie1, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(1);
        if (body.result.length > 0) {
          expect(body.result[0].id).toBeDefined();
          expect(body.result[0].nickname).toBeDefined();
          expect(body.result[0].portraitUri).toBeDefined();
        }
        return done();
      });
    });
  });
  describe('根据手机号查找用户信息', function() {
    it('成功', function(done) {
      return this.testGETAPI("/user/find/86/" + _global.phoneNumber1, _global.userCookie1, 200, {
        code: 200,
        result: {
          id: 'STRING',
          nickname: 'STRING',
          portraitUri: 'STRING'
        }
      }, done);
    });
    it('用户不存在', function(done) {
      return this.testGETAPI("/user/find/86/13912345678", _global.userCookie1, 404, null, done);
    });
    return it('区号+手机号不合法', function(done) {
      return this.testGETAPI("/user/find/86/1391234567", _global.userCookie1, 400, null, done);
    });
  });
  describe('获取当前用户所属群组', function() {
    return it('成功', function(done) {
      return this.testGETAPI("/user/groups", _global.userCookie1, 200, null, function(body) {
        expect(body.result.length).toEqual(0);
        return done();
      });
    });
  });
  describe('通过 Token 修改密码', function() {
    it('成功', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: _global.passwordNew,
        verification_token: verificationCodeToken
      }, 200, {
        code: 200
      }, done);
    });
    it('密码为空', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: '',
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('Token 为空', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: _global.passwordNew,
        verification_token: ''
      }, 400, null, done);
    });
    it('Token 格式错误', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: _global.passwordNew,
        verification_token: '123'
      }, 400, null, done);
    });
    it('Token 不存在', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: _global.passwordNew,
        verification_token: '9a615598-7caa-11e5-a305-525439e49ee9'
      }, 404, null, done);
    });
    it('密码不能包含空格', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: 'qwe qwe',
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    it('密码长度限制-少于6位', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: '123',
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
    return it('密码长度限制-多于20位', function(done) {
      return this.testPOSTAPI('/user/reset_password', {
        password: '01234567890qwe0123456789',
        verification_token: verificationCodeToken
      }, 400, null, done);
    });
  });
  describe('通过旧密码修改密码', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: _global.password,
        oldPassword: _global.passwordNew
      }, 200, {
        code: 200
      }, done);
    });
    it('旧密码为空', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: _global.passwordNew,
        oldPassword: ''
      }, 400, null, done);
    });
    it('新密码为空', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: '',
        oldPassword: _global.password
      }, 400, null, done);
    });
    it('新密码不能包含空格', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: 'qwe qwe',
        oldPassword: _global.password
      }, 400, null, done);
    });
    it('新密码长度限制-少于6位', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: '123',
        oldPassword: _global.password
      }, 400, null, done);
    });
    it('新密码长度限制-多于20位', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: '01234567890qwe0123456789',
        oldPassword: _global.password
      }, 400, null, done);
    });
    return it('密码错误', function(done) {
      return this.testPOSTAPI("/user/change_password", _global.userCookie1, {
        newPassword: _global.passwordNew,
        oldPassword: '123123qwe'
      }, 200, {
        code: 1000
      }, done);
    });
  });
  describe('修改昵称', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/user/set_nickname", _global.userCookie1, {
        nickname: _global.xssString
      }, 200, {
        code: 200
      }, function() {
        return _global.testGETAPI("/user/" + _global.userId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            nickname: _global.filteredString
          }
        }, done);
      });
    });
    it('昵称包含需要转义的字符，转义后长度超过上限', function(done) {
      return this.testPOSTAPI("/user/set_nickname", _global.userCookie1, {
        nickname: '<'.repeat(32)
      }, 200, null, done);
    });
    it('昵称长度大于上限', function(done) {
      return this.testPOSTAPI("/user/set_nickname", _global.userCookie1, {
        nickname: 'a'.repeat(33)
      }, 400, null, done);
    });
    return it('昵称为空', function(done) {
      return this.testPOSTAPI("/user/set_nickname", _global.userCookie1, {
        nickname: ''
      }, 400, null, done);
    });
  });
  describe('设置头像地址', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/user/set_portrait_uri", _global.userCookie1, {
        portraitUri: 'http://a.com/new_address'
      }, 200, {
        code: 200
      }, function() {
        return _global.testGETAPI("/user/" + _global.userId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            portraitUri: 'http://a.com/new_address'
          }
        }, done);
      });
    });
    it('头像地址格式不正确', function(done) {
      return this.testPOSTAPI("/user/set_portrait_uri", _global.userCookie1, {
        portraitUri: 'abcd.com/abcdefgh'
      }, 400, null, done);
    });
    it('头像地址长度大于上限', function(done) {
      return this.testPOSTAPI("/user/set_portrait_uri", _global.userCookie1, {
        portraitUri: 'http://a.co/' + 'a'.repeat(256)
      }, 400, null, done);
    });
    return it('头像地址为空', function(done) {
      return this.testPOSTAPI("/user/set_portrait_uri", _global.userCookie1, {
        portraitUri: ''
      }, 400, null, done);
    });
  });
  describe('加入黑名单列表', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/user/add_to_blacklist", _global.userCookie1, {
        friendId: _global.userId2
      }, 200, {
        code: 200
      }, done);
    });
    it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/user/add_to_blacklist", _global.userCookie1, {
        friendId: null
      }, 400, null, done);
    });
    return it('好友 Id 不存在', function(done) {
      return this.testPOSTAPI("/user/add_to_blacklist", _global.userCookie1, {
        friendId: 'SeWrfDYG8'
      }, 404, null, done);
    });
  });
  describe('获取黑名单列表', function() {
    return it('成功', function(done) {
      return this.testGETAPI("/user/blacklist", _global.userCookie1, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(1);
        if (body.result.length > 0) {
          expect(body.result[0].user.id).toBeDefined();
          expect(body.result[0].user.nickname).toBeDefined();
          expect(body.result[0].user.portraitUri).toBeDefined();
        }
        return done();
      });
    });
  });
  describe('从黑名单列表中移除', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/user/remove_from_blacklist", _global.userCookie1, {
        friendId: _global.userId2
      }, 200, {
        code: 200
      }, done);
    });
    return it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/user/remove_from_blacklist", _global.userCookie1, {
        friendId: null
      }, 400, null, done);
    });
  });
  describe('获取云存储所用 Token', function() {
    it('成功', function(done) {
      return this.testGETAPI("/user/get_image_token", _global.userCookie1, 200, {
        code: 200,
        result: {
          target: 'qiniu',
          token: 'STRING'
        }
      }, done);
    });
    return it('没有登录', function(done) {
      return this.testGETAPI('/user/get_image_token', 403, null, done);
    });
  });
  return describe('注销', function() {
    return it('成功', function(done) {
      return _global.testPOSTAPI("/user/logout", _global.userCookie1, {}, 200, null, function(body, cookie) {
        _global.userCookie1 = cookie;
        return _global.testGETAPI("/user/" + _global.userId1, _global.userCookie1, 403, null, done);
      });
    });
  });
});

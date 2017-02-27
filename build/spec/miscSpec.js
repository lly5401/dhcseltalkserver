describe('其他接口测试', function() {
  var _global;
  _global = null;
  beforeAll(function(done) {
    _global = this;
    return _global.loginUser(_global.phoneNumber2, function(userId, cookie) {
      _global.userId2 = userId;
      _global.userCookie2 = cookie;
      return _global.loginUser(_global.phoneNumber1, function(userId, cookie) {
        _global.userId1 = userId;
        _global.userCookie1 = cookie;
        return done();
      });
    });
  });
  describe('获取最新 Mac 客户端更新信息', function() {
    it('当前版本是旧版本', function(done) {
      return this.testGETAPI('/misc/latest_update?version=1.0.1', 200, {
        url: 'STRING',
        name: 'STRING',
        notes: 'STRING',
        pub_date: 'STRING'
      }, done);
    });
    it('当前版本是最新版本', function(done) {
      return this.testGETAPI('/misc/latest_update?version=1.0.2', 204, null, done);
    });
    it('当前版本大于最新版本', function(done) {
      return this.testGETAPI('/misc/latest_update?version=1.0.3', 204, null, done);
    });
    return it('错误的版本号', function(done) {
      return this.testGETAPI('/misc/latest_update?version=abc', 400, null, done);
    });
  });
  describe('获取最新移动客户端版本信息', function() {
    return it('成功', function(done) {
      return this.testGETAPI('/misc/client_version', 200, {
        iOS: {
          version: 'STRING',
          build: 'STRING',
          url: 'STRING'
        },
        Android: {
          version: 'STRING',
          url: 'STRING'
        }
      }, done);
    });
  });
  describe('获取 Demo 演示所需要的群组和聊天室名单', function() {
    return it('成功', function(done) {
      return this.testGETAPI('/misc/demo_square', 200, {
        code: 200
      }, done);
    });
  });
  return describe('发送消息接口', function() {
    it('接收者不是当前用户的好友', function(done) {
      return this.testPOSTAPI('/misc/send_message', _global.userCookie1, {
        conversationType: 'PRIVATE',
        targetId: _global.userId2,
        objectName: 'RC:TxtMsg',
        content: '{"content":"hello"}',
        pushContent: 'hello'
      }, 403, null, done);
    });
    return it('conversationType 不支持', function(done) {
      return this.testPOSTAPI('/misc/send_message', _global.userCookie1, {
        conversationType: 'SYSTEM',
        targetId: _global.userId2,
        objectName: 'RC:TxtMsg',
        content: '{"content":"hello"}'
      }, 403, null, done);
    });
  });
});

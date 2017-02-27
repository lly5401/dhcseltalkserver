describe('好友接口测试', function() {
  var _global;
  _global = null;
  beforeAll(function(done) {
    _global = this;
    return _global.loginUser(_global.phoneNumber3, function(userId, cookie) {
      _global.userId3 = userId;
      _global.userCookie3 = cookie;
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
  });
  describe('发送好友邀请', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie1, {
        friendId: _global.userId2,
        message: _global.xssString
      }, 200, {
        code: 200,
        result: {
          action: 'Sent'
        }
      }, function(body) {
        return _global.testGETAPI("/friendship/all", _global.userCookie2, 200, {
          code: 200
        }, function(body) {
          expect(body.result.length).toEqual(1);
          if (body.result.length > 0) {
            expect(body.result[0].message).toEqual(_global.filteredString);
          }
          return done();
        });
      });
    });
    it('3天(秒)内重新发出邀请', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie1, {
        friendId: _global.userId2,
        message: 'I am user1'
      }, 200, {
        code: 200,
        result: {
          action: 'None'
        }
      }, done);
    });
    it('3天(秒)后重新发出邀请', function(done) {
      return setTimeout(function() {
        return _global.testPOSTAPI("/friendship/invite", _global.userCookie1, {
          friendId: _global.userId2,
          message: 'I am user1'
        }, 200, {
          code: 200,
          result: {
            action: 'Sent'
          }
        }, done);
      }, 3001);
    });
    it('自己邀请自己成功', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie1, {
        friendId: _global.userId1,
        message: 'I am user1'
      }, 200, {
        code: 200,
        result: {
          action: 'Added'
        }
      }, done);
    });
    it('邀请将自己拉黑的好友', function(done) {
      return this.testPOSTAPI("/user/add_to_blacklist", _global.userCookie3, {
        friendId: _global.userId1
      }, 200, null, function() {
        return _global.testPOSTAPI("/friendship/invite", _global.userCookie1, {
          friendId: _global.userId3,
          message: 'I am user1'
        }, 200, {
          code: 200,
          result: {
            action: 'None'
          }
        }, done);
      });
    });
    it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie1, {
        friendId: null,
        message: 'I am user1'
      }, 400, null, done);
    });
    it('邀请信息为空', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie1, {
        friendId: _global.userId2,
        message: ''
      }, 400, null, done);
    });
    return it('邀请信息长度大于上限', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie1, {
        friendId: _global.userId2,
        message: '12345678901234567890123456789012345678901234567890123456789012345'
      }, 400, null, done);
    });
  });
  describe('忽略好友邀请', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/friendship/ignore", _global.userCookie2, {
        friendId: _global.userId1
      }, 200, null, done);
    });
    it('不是好友', function(done) {
      return this.testPOSTAPI("/friendship/ignore", _global.userCookie2, {
        friendId: '5Vg2XCh9f'
      }, 404, null, done);
    });
    return it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/friendship/ignore", _global.userCookie2, {
        friendId: null
      }, 400, null, done);
    });
  });
  describe('接受好友邀请', function() {
    beforeAll(function(done) {
      return setTimeout(function() {
        return _global.testPOSTAPI("/friendship/invite", _global.userCookie1, {
          friendId: _global.userId2,
          message: 'I am user1'
        }, 200, null, done);
      }, 1001);
    });
    it('成功', function(done) {
      return this.testPOSTAPI("/friendship/agree", _global.userCookie2, {
        friendId: _global.userId1
      }, 200, null, done);
    });
    it('不是好友', function(done) {
      return this.testPOSTAPI("/friendship/agree", _global.userCookie2, {
        friendId: '5Vg2XCh9f'
      }, 404, null, done);
    });
    return it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/friendship/agree", _global.userCookie2, {
        friendId: null
      }, 400, null, done);
    });
  });
  describe('发送消息接口', function() {
    it('成功发送单聊消息', function(done) {
      return this.testPOSTAPI('/misc/send_message', _global.userCookie1, {
        conversationType: 'PRIVATE',
        targetId: _global.userId2,
        objectName: 'RC:TxtMsg',
        content: '{"content":"hello"}',
        pushContent: 'hello'
      }, 200, {
        code: 200
      }, done);
    });
    return it('pushContent 可以为空', function(done) {
      return this.testPOSTAPI('/misc/send_message', _global.userCookie1, {
        conversationType: 'PRIVATE',
        targetId: _global.userId2,
        objectName: 'RC:TxtMsg',
        content: '{"content":"hello"}'
      }, 200, {
        code: 200
      }, done);
    });
  });
  describe('设置好友昵称', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/friendship/set_display_name", _global.userCookie2, {
        friendId: _global.userId1,
        displayName: _global.xssString
      }, 200, {
        code: 200
      }, function(body) {
        return _global.testGETAPI("/friendship/" + _global.userId1 + "/profile", _global.userCookie2, 200, {
          code: 200,
          result: {
            displayName: _global.filteredString
          }
        }, done);
      });
    });
    it('不是好友', function(done) {
      return this.testPOSTAPI("/friendship/set_display_name", _global.userCookie2, {
        friendId: '5Vg2XCh9f',
        displayName: 'Baby'
      }, 404, null, done);
    });
    it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/friendship/set_display_name", _global.userCookie2, {
        friendId: null,
        displayName: 'Baby'
      }, 400, null, done);
    });
    it('好友昵称为空', function(done) {
      return this.testPOSTAPI("/friendship/set_display_name", _global.userCookie2, {
        friendId: _global.userId1,
        displayName: ''
      }, 200, null, done);
    });
    return it('好友昵称长度高于上限', function(done) {
      return this.testPOSTAPI("/friendship/set_display_name", _global.userCookie2, {
        friendId: _global.userId1,
        displayName: '123456789012345678901234567890123'
      }, 400, null, done);
    });
  });
  describe('获取好友详细资料', function() {
    it('成功', function(done) {
      return this.testGETAPI("/friendship/" + _global.userId1 + "/profile", _global.userCookie2, 200, {
        code: 200,
        result: {
          displayName: 'STRING',
          user: {
            id: 'STRING',
            nickname: 'STRING',
            portraitUri: 'STRING',
            region: 'STRING',
            phone: 'STRING'
          }
        }
      }, done);
    });
    return it('不是好友', function(done) {
      return this.testGETAPI("/friendship/5Vg2XCh9f/profile", _global.userCookie2, 403, null, done);
    });
  });
  describe('获取好友列表', function() {
    return it('成功', function(done) {
      return this.testGETAPI("/friendship/all", _global.userCookie2, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(1);
        if (body.result.length > 0) {
          expect(body.result[0].displayName).toBeDefined();
          expect(body.result[0].status).toBeDefined();
          expect(body.result[0].user.id).toBeDefined();
          expect(body.result[0].user.nickname).toBeDefined();
          expect(body.result[0].user.portraitUri).toBeDefined();
        }
        return done();
      });
    });
  });
  describe('删除好友关系', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/friendship/delete", _global.userCookie2, {
        friendId: _global.userId1
      }, 200, null, done);
    });
    it('不是好友', function(done) {
      return this.testPOSTAPI("/friendship/delete", _global.userCookie2, {
        friendId: '5Vg2XCh9f'
      }, 404, null, done);
    });
    return it('好友 Id 为空', function(done) {
      return this.testPOSTAPI("/friendship/delete", _global.userCookie2, {
        friendId: null
      }, 400, null, done);
    });
  });
  return describe('复杂场景测试', function() {
    beforeAll(function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie3, {
        friendId: _global.userId2,
        message: 'I am user3'
      }, 200, null, done);
    });
    it('邀请自己删除过的好友直接成功', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie2, {
        friendId: _global.userId1,
        message: 'I am user2'
      }, 200, null, done);
    });
    it('邀请正在邀请自己的好友直接成功', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie2, {
        friendId: _global.userId3,
        message: 'I am user2'
      }, 200, null, done);
    });
    it('邀请已经是好友关系的好友', function(done) {
      return this.testPOSTAPI("/friendship/invite", _global.userCookie2, {
        friendId: _global.userId1,
        message: 'I am user1'
      }, 400, null, done);
    });
    it('邀请相互删除过的好友', function(done) {
      return this.testPOSTAPI("/friendship/delete", _global.userCookie1, {
        friendId: _global.userId2
      }, 200, null, function() {
        return _global.testPOSTAPI("/friendship/delete", _global.userCookie2, {
          friendId: _global.userId1
        }, 200, null, function() {
          return _global.testPOSTAPI("/friendship/invite", _global.userCookie1, {
            friendId: _global.userId2,
            message: 'I am user1'
          }, 200, null, done);
        });
      });
    });
    return it('邀请删除自己的的好友', function(done) {
      return this.testPOSTAPI("/friendship/delete", _global.userCookie2, {
        friendId: _global.userId3
      }, 200, null, function() {
        return _global.testPOSTAPI("/friendship/invite", _global.userCookie3, {
          friendId: _global.userId2,
          message: 'I am user1'
        }, 200, null, done);
      });
    });
  });
});

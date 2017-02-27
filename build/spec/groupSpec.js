describe('群组接口测试', function() {
  var _global, memberIds1_2, memberIds2_3;
  _global = null;
  memberIds1_2 = null;
  memberIds2_3 = null;
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
          memberIds1_2 = [_global.userId1, _global.userId2];
          memberIds2_3 = [_global.userId2, _global.userId3];
          return done();
        });
      });
    });
  });
  describe('当前用户创建群组', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.xssString,
        memberIds: memberIds1_2
      }, 200, {
        code: 200,
        result: {
          id: 'STRING'
        }
      }, function(body) {
        _global.groupId1 = body.result.id;
        return _global.testGETAPI("/group/" + _global.groupId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            name: _global.filteredString,
            memberCount: 2
          }
        }, function(body) {
          return _global.testGETAPI("/group/" + _global.groupId1 + "/members", _global.userCookie1, 200, {
            code: 200
          }, function(body) {
            expect(body.result.length).toEqual(2);
            return done();
          });
        });
      });
    });
    it('群组成员中不包含创建者', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: memberIds2_3
      }, 400, null, done);
    });
    it('低于群组最大成员上限', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: [_global.userId1]
      }, 400, null, done);
    });
    xit('超过群组最大成员上限', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: [_global.userId1]
      }, 400, null, done);
    });
    xit('用户加入的群组数大于上限', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: [_global.userId1]
      }, 400, null, done);
    });
    it('群组名称长度小于下限', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: 'a',
        memberIds: memberIds1_2
      }, 400, null, done);
    });
    it('群组名称长度大于上限', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: 'a'.repeat(33),
        memberIds: memberIds1_2
      }, 400, null, done);
    });
    it('群组名称为空', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: '',
        memberIds: memberIds1_2
      }, 400, null, done);
    });
    it('群组成员列表为空', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: []
      }, 400, null, done);
    });
    return it('群组成员列表中有空项目', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: [_global.userId1, null]
      }, 400, null, done);
    });
  });
  describe('创建者为群组重命名', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie1, {
        groupId: _global.groupId1,
        name: _global.xssString + 'a'
      }, 200, null, function() {
        return _global.testGETAPI("/group/" + _global.groupId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            name: _global.filteredString + 'a'
          }
        }, done);
      });
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie3, {
        groupId: _global.groupId1,
        name: 'New Name'
      }, 400, null, done);
    });
    it('不是群组创建者', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie3, {
        groupId: _global.groupId1,
        name: 'New Name'
      }, 400, null, done);
    });
    it('群组名称长度小于下限', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie1, {
        groupId: _global.groupId1,
        name: 'o'
      }, 400, null, done);
    });
    it('群组名称长度大于上限', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie1, {
        groupId: _global.groupId1,
        name: 'a'.repeat(33)
      }, 400, null, done);
    });
    it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie1, {
        groupId: null,
        name: 'New Name'
      }, 400, null, done);
    });
    return it('群组名称为空', function(done) {
      return this.testPOSTAPI("/group/rename", _global.userCookie1, {
        groupId: _global.groupId1,
        name: ''
      }, 400, null, done);
    });
  });
  describe('创建者设置群组头像地址', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie1, {
        groupId: _global.groupId1,
        portraitUri: 'http://a.com/new_address'
      }, 200, null, function() {
        return _global.testGETAPI("/group/" + _global.groupId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            portraitUri: 'http://a.com/new_address'
          }
        }, done);
      });
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie3, {
        groupId: _global.groupId1,
        portraitUri: 'http://a.com/new_address'
      }, 400, null, done);
    });
    it('不是群组创建者', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie3, {
        groupId: _global.groupId1,
        portraitUri: 'http://a.com/new_address'
      }, 400, null, done);
    });
    it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie1, {
        groupId: null,
        portraitUri: 'http://a.com/new_address'
      }, 400, null, done);
    });
    it('群组头像地址格式不正确', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie1, {
        groupId: _global.groupId1,
        portraitUri: 'abcd.com/abcdefgh'
      }, 400, null, done);
    });
    it('群组头像地址长度大于上限', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie1, {
        groupId: _global.groupId1,
        portraitUri: 'http://a.co/' + 'a'.repeat(256)
      }, 400, null, done);
    });
    return it('群组头像地址为空', function(done) {
      return this.testPOSTAPI("/group/set_portrait_uri", _global.userCookie1, {
        groupId: _global.groupId1,
        portraitUri: ''
      }, 400, null, done);
    });
  });
  describe('设置当前用户在群组中的屏显名', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/set_display_name", _global.userCookie1, {
        groupId: _global.groupId1,
        displayName: _global.xssString
      }, 200, null, function(body) {
        return _global.testGETAPI("/group/" + _global.groupId1 + "/members", _global.userCookie1, 200, {
          code: 200
        }, function(body) {
          expect(body.result[0].displayName).toEqual(_global.filteredString);
          return done();
        });
      });
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/set_display_name", _global.userCookie3, {
        groupId: '5Vg2XCh9f',
        displayName: 'New Name'
      }, 404, null, done);
    });
    it('屏显名长度大于上限', function(done) {
      return this.testPOSTAPI("/group/set_display_name", _global.userCookie1, {
        groupId: _global.groupId1,
        displayName: 'a'.repeat(33)
      }, 400, null, done);
    });
    it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/set_display_name", _global.userCookie1, {
        groupId: null,
        displayName: 'New Name'
      }, 400, null, done);
    });
    return it('屏显名为空', function(done) {
      return this.testPOSTAPI("/group/set_display_name", _global.userCookie1, {
        groupId: _global.groupId1,
        displayName: ''
      }, 200, null, done);
    });
  });
  describe('获取当前用户所属所有群组列表', function() {
    it('成功，不为空', function(done) {
      return this.testGETAPI("/user/groups", _global.userCookie1, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(1);
        if (body.result.length > 0) {
          expect(body.result[0].role).toBeDefined();
          expect(body.result[0].group.id).toBeDefined();
          expect(body.result[0].group.name).toBeDefined();
          expect(body.result[0].group.portraitUri).toBeDefined();
          expect(body.result[0].group.memberCount).toBeDefined();
          expect(body.result[0].group.maxMemberCount).toBeDefined();
        }
        return done();
      });
    });
    return it('成功，为空', function(done) {
      return this.testGETAPI("/user/groups", _global.userCookie3, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toEqual(0);
        return done();
      });
    });
  });
  describe('获取群组成员', function() {
    it('成功', function(done) {
      return this.testGETAPI("/group/" + _global.groupId1 + "/members", _global.userCookie1, 200, {
        code: 200
      }, function(body) {
        expect(body.result.length).toBeGreaterThan(1);
        if (body.result.length > 0) {
          expect(body.result[0].displayName).toBeDefined();
          expect(body.result[0].role).toBeDefined();
          expect(body.result[0].createdAt).toBeDefined();
          expect(body.result[0].user.id).toBeDefined();
          expect(body.result[0].user.nickname).toBeDefined();
          expect(body.result[0].user.portraitUri).toBeDefined();
        }
        return done();
      });
    });
    it('群组 Id 不存在', function(done) {
      return this.testGETAPI("/group/5Vg2XCh9f/members", _global.userCookie1, 404, null, done);
    });
    return it('当前用户不是群组成员', function(done) {
      return this.testGETAPI("/group/" + _global.groupId1 + "/members", _global.userCookie3, 403, null, done);
    });
  });
  describe('群组创建者添加群组成员', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [_global.userId3]
      }, 200, null, function() {
        return _global.testGETAPI("/group/" + _global.groupId1, _global.userCookie1, 200, {
          code: 200,
          result: {
            memberCount: 3
          }
        }, function(body) {
          return _global.testGETAPI("/group/" + _global.groupId1 + "/members", _global.userCookie1, 200, {
            code: 200
          }, function(body) {
            expect(body.result.length).toEqual(3);
            return done();
          });
        });
      });
    });
    it('添加删除过的群组成员成功', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [_global.userId3]
      }, 200, null, function() {
        return _global.testPOSTAPI("/group/add", _global.userCookie1, {
          groupId: _global.groupId1,
          memberIds: [_global.userId3]
        }, 200, null, function() {
          return _global.testGETAPI("/group/" + _global.groupId1, _global.userCookie1, 200, {
            code: 200
          }, function(body) {
            expect(body.result.memberCount).toEqual(3);
            return _global.testGETAPI("/group/" + _global.groupId1 + "/members", _global.userCookie1, 200, {
              code: 200
            }, function(body) {
              expect(body.result.length).toEqual(3);
              return done();
            });
          });
        });
      });
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: '5Vg2XCh9f',
        memberIds: [_global.userId3]
      }, 404, null, done);
    });
    it('重复添加了当前用户', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [_global.userId1]
      }, 400, null, done);
    });
    it('重复添加群组成员', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [_global.userId3]
      }, 400, null, done);
    });
    xit('用户加入的群组数大于上限', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie3, {
        groupId: _global.groupId1,
        memberIds: [3]
      }, 400, null, done);
    });
    xit('超过群组最大成员上限', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie3, {
        groupId: _global.groupId1,
        memberIds: [3]
      }, 400, null, done);
    });
    it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: null,
        memberIds: []
      }, 400, null, done);
    });
    it('群组成员列表为空', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: []
      }, 400, null, done);
    });
    return it('群组成员列表中有空项目', function(done) {
      return this.testPOSTAPI("/group/add", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [null]
      }, 400, null, done);
    });
  });
  describe('创建者将用户踢出群组', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [_global.userId3]
      }, 200, null, done);
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: '5Vg2XCh9f',
        memberIds: [3]
      }, 404, null, done);
    });
    it('当前用户不是群组创建者', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie3, {
        groupId: _global.groupId1,
        memberIds: [3]
      }, 403, null, done);
    });
    it('将创建者自己踢出群组', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [_global.userId1]
      }, 400, null, done);
    });
    it('群组成员 Id 不是群组成员', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: ['5Vg2XCh9f']
      }, 400, null, done);
    });
    it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: null,
        memberIds: [3]
      }, 400, null, done);
    });
    it('群组成员 Id 列表为空', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: []
      }, 400, null, done);
    });
    return it('群组成员 Id 列表中有空项目', function(done) {
      return this.testPOSTAPI("/group/kick", _global.userCookie1, {
        groupId: _global.groupId1,
        memberIds: [null]
      }, 400, null, done);
    });
  });
  describe('当前用户加入某群组', function() {
    beforeAll(function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie2, {
        name: _global.groupName2,
        memberIds: memberIds2_3
      }, 200, {
        code: 200
      }, function(body) {
        _global.groupId2 = body.result.id;
        return done();
      });
    });
    it('成功', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie1, {
        groupId: _global.groupId2
      }, 200, null, done);
    });
    it('加入自己曾经被踢出过群组', function(done) {
      return this.testGETAPI("/group/" + _global.groupId2 + "/members", _global.userCookie3, 200, {
        code: 200
      }, function() {
        return _global.testPOSTAPI("/group/kick", _global.userCookie2, {
          groupId: _global.groupId2,
          memberIds: [_global.userId3]
        }, 200, null, function() {
          return _global.testPOSTAPI("/group/join", _global.userCookie3, {
            groupId: _global.groupId2
          }, 200, null, done);
        });
      });
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie1, {
        groupId: '5Vg2XCh9f'
      }, 404, null, done);
    });
    it('重复加入群组', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie3, {
        groupId: _global.groupId2
      }, 400, null, done);
    });
    it('已经是群组成员', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie1, {
        groupId: _global.groupId2
      }, 400, null, done);
    });
    xit('用户加入的群组数大于上限', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie3, {
        groupId: _global.groupId1,
        memberIds: [3]
      }, 400, null, done);
    });
    xit('超过群组最大成员上限', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie1, {
        groupId: _global.groupId2
      }, 400, null, done);
    });
    return it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/join", _global.userCookie1, {
        groupId: null
      }, 400, null, done);
    });
  });
  describe('当前用户退出群组', function() {
    it('成功', function(done) {
      return this.testPOSTAPI("/group/quit", _global.userCookie1, {
        groupId: _global.groupId2
      }, 200, null, done);
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/quit", _global.userCookie1, {
        groupId: '5Vg2XCh9f'
      }, 404, null, done);
    });
    it('当前用户不是群组成员', function(done) {
      return this.testPOSTAPI("/group/quit", _global.userCookie3, {
        groupId: _global.groupId1
      }, 403, null, done);
    });
    it('退出并解散群组', function(done) {
      return this.testPOSTAPI("/group/quit", _global.userCookie2, {
        groupId: _global.groupId2
      }, 200, null, function() {
        return _global.testPOSTAPI("/group/quit", _global.userCookie3, {
          groupId: _global.groupId2
        }, 200, null, done);
      });
    });
    return it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/quit", _global.userCookie1, {
        groupId: null
      }, 400, null, done);
    });
  });
  describe('发送消息接口', function() {
    it('成功发送群消息', function(done) {
      return this.testPOSTAPI('/misc/send_message', _global.userCookie1, {
        conversationType: 'GROUP',
        targetId: _global.groupId1,
        objectName: 'RC:TxtMsg',
        content: '{"content":"hello"}',
        pushContent: 'hello'
      }, 200, {
        code: 200
      }, done);
    });
    return it('当前用户不属于目标群', function(done) {
      return this.testPOSTAPI('/misc/send_message', _global.userCookie2, {
        conversationType: 'GROUP',
        targetId: _global.groupId2,
        objectName: 'RC:TxtMsg',
        content: '{"content":"hello"}',
        pushContent: 'hello'
      }, 403, null, done);
    });
  });
  describe('获取群组信息', function() {
    it('成功获取存在的群组', function(done) {
      return this.testGETAPI("/group/" + _global.groupId1, _global.userCookie1, 200, {
        code: 200,
        result: {
          id: 'STRING',
          name: 'STRING',
          portraitUri: 'STRING',
          memberCount: 'INTEGER',
          creatorId: 'STRING',
          maxMemberCount: 'INTEGER'
        }
      }, done);
    });
    it('成功获取已经解散的群组', function(done) {
      return this.testGETAPI("/group/" + _global.groupId2, _global.userCookie1, 200, {
        code: 200,
        result: {
          id: 'STRING',
          name: 'STRING',
          portraitUri: 'STRING',
          memberCount: 'INTEGER',
          creatorId: 'STRING',
          deletedAt: 'STRING',
          maxMemberCount: 'INTEGER'
        }
      }, done);
    });
    return it('群组 Id 不存在', function(done) {
      return this.testGETAPI("/group/5Vg2XCh9f", _global.userCookie1, 404, null, done);
    });
  });
  describe('用户登录同步群组', function() {
    return it('成功', function(done) {
      return this.testPOSTAPI('/user/login', {
        region: '86',
        phone: _global.phoneNumber1,
        password: _global.password
      }, 200, {
        code: 200,
        result: {
          id: _global.userId1
        }
      }, function(body, cookie) {
        expect(cookie).not.toBeNull();
        return done();
      });
    });
  });
  describe('解散群组', function() {
    it('当前用户不是群组创建者', function(done) {
      return this.testPOSTAPI("/group/dismiss", _global.userCookie2, {
        groupId: _global.groupId1
      }, 400, null, done);
    });
    it('成功', function(done) {
      return this.testPOSTAPI("/group/dismiss", _global.userCookie1, {
        groupId: _global.groupId1
      }, 200, null, done);
    });
    it('群组 Id 不存在', function(done) {
      return this.testPOSTAPI("/group/dismiss", _global.userCookie1, {
        groupId: '5Vg2XCh9f'
      }, 400, null, done);
    });
    it('群组 Id 为空', function(done) {
      return this.testPOSTAPI("/group/dismiss", _global.userCookie1, {
        groupId: null
      }, 400, null, done);
    });
    return it('创建一个解散的群组成功', function(done) {
      return this.testPOSTAPI("/group/create", _global.userCookie1, {
        name: _global.groupName1,
        memberIds: memberIds1_2
      }, 200, {
        code: 200,
        result: {
          id: 'STRING'
        }
      }, done);
    });
  });
  return describe('同步数据', function() {
    it('成功，有数据', function(done) {
      return this.testGETAPI("/user/sync/123", _global.userCookie1, 200, {
        code: 200,
        result: {
          version: 'INTEGER'
        }
      }, function(body) {
        _global.version = body.result.version;
        return done();
      });
    });
    it('成功，无数据', function(done) {
      return this.testGETAPI("/user/sync/" + _global.version, _global.userCookie1, 200, {
        code: 200,
        result: {
          version: 'NULL'
        }
      }, done);
    });
    return it('失败，参数错误', function(done) {
      return this.testGETAPI("/user/sync/abc", _global.userCookie1, 400, null, done);
    });
  });
});

describe '其他接口测试', ->
  _global = null

  beforeAll (done) ->
    _global = this

    # 获取 userId 信息，登录 userId1
    _global.loginUser _global.phoneNumber2, (userId, cookie) ->
      _global.userId2 = userId
      _global.userCookie2 = cookie
      _global.loginUser _global.phoneNumber1, (userId, cookie) ->
        _global.userId1 = userId
        _global.userCookie1 = cookie
        done()

  describe '获取最新 Mac 客户端更新信息', ->

    it '当前版本是旧版本', (done) ->
      this.testGETAPI '/misc/latest_update?version=1.0.1'
      , 200
      ,
        url: 'STRING'
        name: 'STRING'
        notes: 'STRING'
        pub_date: 'STRING'
      , done

    it '当前版本是最新版本', (done) ->
      this.testGETAPI '/misc/latest_update?version=1.0.2'
      , 204
      , null
      , done

    it '当前版本大于最新版本', (done) ->
      this.testGETAPI '/misc/latest_update?version=1.0.3'
      , 204
      , null
      , done

    it '错误的版本号', (done) ->
      this.testGETAPI '/misc/latest_update?version=abc'
      , 400
      , null
      , done

  describe '获取最新移动客户端版本信息', ->

    it '成功', (done) ->
      this.testGETAPI '/misc/client_version'
      , 200
      ,
        iOS:
          version: 'STRING'
          build: 'STRING'
          url: 'STRING'
        Android:
          version: 'STRING'
          url: 'STRING'
      , done

  describe '获取 Demo 演示所需要的群组和聊天室名单', ->

    it '成功', (done) ->
      this.testGETAPI '/misc/demo_square'
      , 200
      , code: 200
      , done

  describe '发送消息接口', ->

    it '接收者不是当前用户的好友', (done) ->
      this.testPOSTAPI '/misc/send_message', _global.userCookie1,
        conversationType: 'PRIVATE'
        targetId: _global.userId2
        objectName: 'RC:TxtMsg'
        content: '{"content":"hello"}'
        pushContent: 'hello'
      , 403
      , null
      , done

    it 'conversationType 不支持', (done) ->
      this.testPOSTAPI '/misc/send_message', _global.userCookie1,
        conversationType: 'SYSTEM'
        targetId: _global.userId2
        objectName: 'RC:TxtMsg'
        content: '{"content":"hello"}'
      , 403
      , null
      , done

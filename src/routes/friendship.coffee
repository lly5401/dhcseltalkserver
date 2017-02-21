express   = require 'express'
moment    = require 'moment'
rongCloud = require 'rongcloud-sdk'

Config    = require '../conf'
Session   = require '../util/session'
Utility   = require('../util/util').Utility
APIResult = require('../util/util').APIResult

# 引用数据库对象和模型
[sequelize, User, Blacklist, Friendship, Group, GroupMember, GroupSync, DataVersion, VerificationCode, LoginLog] = require '../db'

FRIENDSHIP_REQUESTING = 10
FRIENDSHIP_REQUESTED  = 11
FRIENDSHIP_AGREED     = 20
FRIENDSHIP_IGNORED    = 21
FRIENDSHIP_DELETED    = 30

FRIEND_REQUEST_MESSAGE_MIN_LENGTH = 0
FRIEND_REQUEST_MESSAGE_MAX_LENGTH = 64

FRIEND_DISPLAY_NAME_MIN_LENGTH = 1
FRIEND_DISPLAY_NAME_MAX_LENGTH = 32

CONTACT_OPERATION_ACCEPT_RESPONSE = 'AcceptResponse'
CONTACT_OPERATION_REQUEST         = 'Request'

# 初始化融云 Server API SDK
rongCloud.init Config.RONGCLOUD_APP_KEY, Config.RONGCLOUD_APP_SECRET

sendContactNotification = (userId, nickname, friendId, operation, message, timestamp) ->
  encodedUserId = Utility.encodeId userId
  encodedFriendId = Utility.encodeId friendId

  contactNotificationMessage =
    operation: operation
    sourceUserId: encodedUserId
    targetUserId: encodedFriendId
    message: message
    extra:
      sourceUserNickname: nickname
      version: timestamp

  Utility.log 'Sending ContactNotificationMessage:', JSON.stringify contactNotificationMessage

  rongCloud.message.system.publish encodedUserId, [encodedFriendId], 'RC:ContactNtf', contactNotificationMessage,
    (err, resultText) ->
      # 暂不考虑回调的结果是否成功，后续可以考虑记录到系统错误日志中
      if err
        Utility.logError 'Error: send contact notification failed: %j', err

router = express.Router()

validator = sequelize.Validator

# 发送邀请好友
router.post '/invite', (req, res, next) ->
  friendId = req.body.friendId
  message  = Utility.xss req.body.message, FRIEND_REQUEST_MESSAGE_MAX_LENGTH

  if not validator.isLength message, FRIEND_REQUEST_MESSAGE_MIN_LENGTH, FRIEND_REQUEST_MESSAGE_MAX_LENGTH
    return res.status(400).send 'Length of friend request message is out of limit.'

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Utility.log '%s invite user -> %s', currentUserId, friendId

  Promise.all [
    Friendship.getInfo currentUserId, friendId
  ,
    Friendship.getInfo friendId, currentUserId
  ,
    Blacklist.findOne
      where:
        userId: friendId
        friendId: currentUserId
      attributes: [
        'status'
      ]
  ]
  .then ([fg, fd, blacklist]) ->
    Utility.log 'Friendship requesting: %j', fg
    Utility.log 'Friendship requested:  %j', fd

    # 被对方拉黑后，不进行任何后续操作了
    if blacklist and blacklist.status
      # Do nothing.
      Utility.log 'Invite result: %s %s', 'None: blacklisted by friend', 'Do nothing.'
      return res.send new APIResult 200, action: 'None', 'Do nothing.'

    action = 'Added'
    resultMessage = 'Friend added.'

    if fg and fd
      # 已经是好友，错误的请求
      if fg.status is FRIENDSHIP_AGREED and fd.status is FRIENDSHIP_AGREED
        return res.status(400).send "User #{friendId} is already your friend."

      # 开发测试环境中单位改为秒，生产环境为天
      if req.app.get('env') is 'development'
        unit = 's'
      else
        unit = 'd'

      # 对方发出过邀请，直接同意
      if fd.status is FRIENDSHIP_REQUESTING
        fgStatus = FRIENDSHIP_AGREED
        fdStatus = FRIENDSHIP_AGREED
        message = fd.message
      # 对方同意过（即目前是单向好友），直接同意
      else if fd.status is FRIENDSHIP_AGREED
        fgStatus = FRIENDSHIP_AGREED
        fdStatus = FRIENDSHIP_AGREED
        message = fd.message
        timestamp = fd.timestamp
      # 双方都删除了对方，或者，被对方删除，或者，被对方忽略一天之后，或者，发出过邀请三天之后，重新发出邀请
      else if (fd.status is FRIENDSHIP_DELETED and fg.status is FRIENDSHIP_DELETED) or (fg.status is FRIENDSHIP_AGREED and fd.status is FRIENDSHIP_DELETED) or (fg.status is FRIENDSHIP_REQUESTING and fd.status is FRIENDSHIP_IGNORED and moment().subtract(1, unit).isAfter fg.updatedAt) or (fg.status is FRIENDSHIP_REQUESTING and fd.status is FRIENDSHIP_REQUESTED and moment().subtract(3, unit).isAfter fg.updatedAt)
        fgStatus = FRIENDSHIP_REQUESTING
        fdStatus = FRIENDSHIP_REQUESTED
        action = 'Sent'
        resultMessage = 'Request sent.'
      else
        # Do nothing.
        Utility.log 'Invite result: %s %s', 'None', 'Do nothing.'
        return res.send new APIResult 200, action: 'None', 'Do nothing.'

      sequelize.transaction (t) ->
        Promise.all [
          fg.update
            status: fgStatus
            timestamp: timestamp
          ,
            transaction: t
        ,
          fd.update
            status: fdStatus
            timestamp: timestamp
            message: message
          ,
            transaction: t
        ]
        .then ->
          # 更新版本号（时间戳）
          DataVersion.updateFriendshipVersion currentUserId, timestamp
          .then ->
            # 重新发出了邀请，所以要更新版本号（时间戳）
            if fd.status is FRIENDSHIP_REQUESTED
              DataVersion.updateFriendshipVersion friendId, timestamp
              .then ->
                Session.getCurrentUserNickname currentUserId, User
                .then (nickname) ->
                  sendContactNotification currentUserId,
                    nickname,
                    friendId,
                    CONTACT_OPERATION_REQUEST,
                    message,
                    timestamp

                Utility.log 'Invite result: %s %s', action, resultMessage
                res.send new APIResult 200, action: action, resultMessage
            else
              Utility.log 'Invite result: %s %s', action, resultMessage
              res.send new APIResult 200, action: action, resultMessage
    else
      # 自己邀请自己，直接同意。可以自己是自己的好友，方便测试和当临时记事本用。
      if friendId is currentUserId
        # 创建好友请求关系
        Promise.all [
          Friendship.create
            userId: currentUserId
            friendId: friendId
            message: ''
            status: FRIENDSHIP_AGREED
            timestamp: timestamp
        ,
          # 更新版本号（时间戳）
          DataVersion.updateFriendshipVersion currentUserId, timestamp
        ]
        .then ->
          Utility.log 'Invite result: %s %s', action, resultMessage
          res.send new APIResult 200, action: action, resultMessage
      else
        # 创建好友请求关系
        sequelize.transaction (t) ->
          Promise.all [
            Friendship.create
              userId: currentUserId
              friendId: friendId
              message: ''
              status: FRIENDSHIP_REQUESTING
              timestamp: timestamp
            ,
              transaction: t
          ,
            Friendship.create
              userId: friendId
              friendId: currentUserId
              message: message
              status: FRIENDSHIP_REQUESTED
              timestamp: timestamp
            ,
              transaction: t
          ]
          .then ->
            # 更新版本号（时间戳）
            Promise.all [
              DataVersion.updateFriendshipVersion currentUserId, timestamp
            ,
              DataVersion.updateFriendshipVersion friendId, timestamp
            ]
            .then ->
              Session.getCurrentUserNickname currentUserId, User
              .then (nickname) ->
                sendContactNotification currentUserId,
                  nickname,
                  friendId,
                  CONTACT_OPERATION_REQUEST,
                  message,
                  timestamp

              Utility.log 'Invite result: %s %s', 'Sent', 'Request sent.'
              res.send new APIResult 200, action: 'Sent', 'Request sent.'
  .catch next

# 同意好友邀请
router.post '/agree', (req, res, next) ->
  friendId = req.body.friendId

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Utility.log '%s agreed to user -> %s', currentUserId, friendId

  sequelize.transaction (t) ->
    Friendship.update
      status: FRIENDSHIP_AGREED
      timestamp: timestamp
    ,
      where:
        userId: currentUserId
        friendId: friendId
        status: FRIENDSHIP_REQUESTED
      transaction: t
    .then ([affectedCount]) ->
      if affectedCount is 0
        return res.status(404).send 'Unknown friend user or invalid status.'

      Friendship.update
        status: FRIENDSHIP_AGREED
        timestamp: timestamp
      ,
        where:
          userId: friendId
          friendId: currentUserId
          #status: FRIENDSHIP_REQUESTING # 不判断了，直接更新
        transaction: t
      .then -> # 不判断是否更新了，数据库异常直接作为脏数据
        # 更新版本号（时间戳）
        Promise.all [
          DataVersion.updateFriendshipVersion currentUserId, timestamp
          DataVersion.updateFriendshipVersion friendId, timestamp
        ]
        .then ->
          Session.getCurrentUserNickname currentUserId, User
          .then (nickname) ->
            sendContactNotification currentUserId,
              nickname,
              friendId,
              CONTACT_OPERATION_ACCEPT_RESPONSE,
              '',
              timestamp

          res.send new APIResult 200
  .catch next

# 忽略好友请求
router.post '/ignore', (req, res, next) ->
  friendId = req.body.friendId

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Friendship.update
    status: FRIENDSHIP_IGNORED
    timestamp: timestamp
  ,
    where:
      userId: currentUserId
      friendId: friendId
      status: FRIENDSHIP_REQUESTED
  .then ([affectedCount]) ->
    if affectedCount is 0
      return res.status(404).send 'Unknown friend user or invalid status.'

    # 更新版本号（时间戳）
    DataVersion.updateFriendshipVersion currentUserId, timestamp
    .then ->
      res.send new APIResult 200
  .catch next

# 删除好友
router.post '/delete', (req, res, next) ->
  friendId = req.body.friendId

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Friendship.update
    status: FRIENDSHIP_DELETED
    displayName: ''
    message: ''
    timestamp: timestamp
  ,
    where:
      userId: currentUserId
      friendId: friendId
      status: FRIENDSHIP_AGREED
  .then ([affectedCount]) ->
    if affectedCount is 0
      return res.status(404).send 'Unknown friend user or invalid status.'

    # 更新版本号（时间戳）
    DataVersion.updateFriendshipVersion currentUserId, timestamp
    .then ->
      res.send new APIResult 200
  .catch next

# 设置好友备注名
router.post '/set_display_name', (req, res, next) ->
  friendId    = req.body.friendId
  displayName = Utility.xss req.body.displayName, FRIEND_REQUEST_MESSAGE_MAX_LENGTH

  if (displayName isnt '') and not validator.isLength displayName, FRIEND_DISPLAY_NAME_MIN_LENGTH, FRIEND_DISPLAY_NAME_MAX_LENGTH
    return res.status(400).send 'Length of displayName is out of limit.'

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Friendship.update
    displayName: displayName
    timestamp: timestamp
  ,
    where:
      userId: currentUserId
      friendId: friendId
      status: FRIENDSHIP_AGREED
  .then ([affectedCount]) ->
    if affectedCount is 0
      return res.status(404).send 'Unknown friend user or invalid status.'

    # 更新版本号（时间戳）
    DataVersion.updateFriendshipVersion currentUserId, timestamp
    .then ->
      res.send new APIResult 200
  .catch next

# 获取好友列表
router.get '/all', (req, res, next) ->
  Friendship.findAll
    where:
      userId: Session.getCurrentUserId req
    attributes: [
      'displayName'
      'message'
      'status'
      'updatedAt'
    ]
    include:
      model: User
      attributes: [
        'id'
        'nickname'
        'portraitUri'
      ]
  .then (friends) ->
    # 为节约服务端资源，客户端自己排序
    res.send new APIResult 200, Utility.encodeResults friends, [['user', 'id']]
  .catch next

# 获取好友详细资料
router.get '/:id/profile', (req, res, next) ->
  userId = req.params.id

  userId = Utility.decodeIds userId

  # 只可以看好友的（好友状态为被对方同意）
  Friendship.findOne
    where:
      userId: Session.getCurrentUserId req
      friendId: userId
      status: FRIENDSHIP_AGREED
    attributes: [
      'displayName'
    ]
    include:
      model: User
      attributes: [
        'id'
        # 'username'
        'nickname'
        'region'
        'phone'
        'portraitUri'
      ]
  .then (friend) ->
    if not friend
      return res.status(403).send "Current user is not friend of user #{userId}."

    res.send new APIResult 200, Utility.encodeResults friend, [['user', 'id']]
  .catch next

module.exports = router

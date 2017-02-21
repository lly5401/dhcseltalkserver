express   = require 'express'
_         = require 'underscore'
jsonfile  = require 'jsonfile'
path      = require 'path'
semver    = require 'semver'
rongCloud = require 'rongcloud-sdk'

Config    = require '../conf'
Session   = require '../util/session'
Utility   = require('../util/util').Utility
APIResult = require('../util/util').APIResult

# 引用数据库对象和模型
[sequelize, User, Blacklist, Friendship, Group, GroupMember] = require '../db'

FRIENDSHIP_AGREED = 20

# 初始化融云 Server API SDK
rongCloud.init Config.RONGCLOUD_APP_KEY, Config.RONGCLOUD_APP_SECRET

router = express.Router()

# 获取最新 Mac 客户端更新信息
router.get '/latest_update', (req, res, next) ->
  clientVersion = req.query.version

  try
    squirrelConfig = jsonfile.readFileSync path.join __dirname, '../squirrel.json'

    if (semver.valid(clientVersion) is null) or (semver.valid(squirrelConfig.version) is null)
      return res.status(400).send 'Invalid version.'

    if semver.gte(clientVersion, squirrelConfig.version)
      res.status(204).end()
    else
      res.send squirrelConfig
  catch err
    next err

# 获取最新移动客户端版本信息
router.get '/client_version', (req, res, next) ->
  try
    clientVersionInfo = jsonfile.readFileSync path.join __dirname, '../client_version.json'

    res.send clientVersionInfo
  catch err
    next err

# 获取 Demo 演示所需要的群组和聊天室名单
router.get '/demo_square', (req, res, next) ->
  try
    demoSquareData = jsonfile.readFileSync path.join __dirname, '../demo_square.json'

    groupIds = _.chain(demoSquareData).where({ type: 'group' }).pluck('id').value()

    Group.findAll
      where:
        id:
          $in:
            groupIds
      attributes: [
        'id'
        'name'
        'portraitUri'
        'memberCount'
      ]
    .then (groups) ->
      demoSquareData.forEach (item) ->
        if item.type is 'group'
          group = _.findWhere(groups, { id: item.id })
          group = { name: 'Unknown', portraitUri: '', memberCount: 0 } if not group

          item.name = group.name
          item.portraitUri = group.portraitUri
          item.memberCount = group.memberCount
          item.maxMemberCount = group.maxMemberCount

      res.send new APIResult 200, Utility.encodeResults demoSquareData
  catch err
    next err

# 发送消息
router.post '/send_message', (req, res, next) ->
  conversationType = req.body.conversationType
  targetId         = req.body.targetId
  objectName       = req.body.objectName
  content          = req.body.content
  pushContent      = req.body.pushContent
  encodedTargetId  = req.body.encodedTargetId

  currentUserId = Session.getCurrentUserId req
  encodedCurrentUserId = Utility.encodeId currentUserId

  switch conversationType
    when 'PRIVATE'
      # Target user MUST be friend of current user.
      Friendship.count
        where:
          userId: currentUserId
          friendId: targetId
          status: FRIENDSHIP_AGREED
      .then (count) ->
        if count > 0
          rongCloud.message.private.publish encodedCurrentUserId, encodedTargetId, objectName, content, pushContent,
            (err, resultText) ->
              # 暂不考虑回调的结果是否成功，后续可以考虑记录到系统错误日志中
              if err
                Utility.logError 'Error: send message failed: %j', err
                throw err

              res.send new APIResult 200
        else
          res.status(403).send "User #{encodedTargetId} is not your friend."
    when 'GROUP'
      # Current user MUST be member of target group.
      GroupMember.count
        where:
          groupId: targetId
          memberId: currentUserId
      .then (count) ->
        if count > 0
          rongCloud.message.group.publish encodedCurrentUserId, encodedTargetId, objectName, content, pushContent,
            (err, resultText) ->
              # 暂不考虑回调的结果是否成功，后续可以考虑记录到系统错误日志中
              if err
                Utility.logError 'Error: send message failed: %j', err
                throw err

              res.send new APIResult 200
        else
          res.status(403).send "Your are not member of Group #{encodedTargetId}."
    else
      res.status(403).send 'Unsupported conversation type.'

module.exports = router

express   = require 'express'
co        = require 'co'
_         = require 'underscore'
rongCloud = require 'rongcloud-sdk'

Config    = require '../conf'
Session   = require '../util/session'
Utility   = require('../util/util').Utility
APIResult = require('../util/util').APIResult
HTTPError = require('../util/util').HTTPError

# 引用数据库对象和模型
[sequelize, User, Blacklist, Friendship, Group, GroupMember, GroupSync, DataVersion, VerificationCode, LoginLog] = require '../db'

GROUP_CREATOR = 0
GROUP_MEMBER  = 1

GROUP_NAME_MIN_LENGTH = 2
GROUP_NAME_MAX_LENGTH = 32

PORTRAIT_URI_MIN_LENGTH = 12
PORTRAIT_URI_MAX_LENGTH = 256

GROUP_MEMBER_DISPLAY_NAME_MIN_LENGTH = 1
GROUP_MEMBER_DISPLAY_NAME_MAX_LENGTH = 32

DEFAULT_MAX_GROUP_MEMBER_COUNT = 500
MAX_USER_GROUP_OWN_COUNT = 500

GROUP_OPERATION_CREATE  = 'Create'
GROUP_OPERATION_ADD     = 'Add'
GROUP_OPERATION_QUIT    = 'Quit'
GROUP_OPERATION_DISMISS = 'Dismiss'
GROUP_OPERATION_KICKED  = 'Kicked'
GROUP_OPERATION_RENAME  = 'Rename'
# GROUP_OPERATION_BULLETIN = 'Bulletin' # 暂时不需要

# 融云 Server API SDK
rongCloud.init Config.RONGCLOUD_APP_KEY, Config.RONGCLOUD_APP_SECRET

sendGroupNotification = (userId, groupId, operation, data) ->
  encodedUserId = Utility.encodeId userId
  encodedGroupId = Utility.encodeId groupId

  data.data = JSON.parse JSON.stringify data

  groupNotificationMessage =
    operatorUserId: encodedUserId
    operation: operation
    data: data
    message: ''

  Utility.log 'Sending GroupNotificationMessage:', JSON.stringify groupNotificationMessage

  new Promise (resolve, reject) ->
    rongCloud.message.group.publish '__system__', encodedGroupId, 'RC:GrpNtf', groupNotificationMessage,
      (err, resultText) ->
        # 暂不考虑回调的结果是否成功，后续可以考虑记录到系统错误日志中
        if err
          Utility.logError 'Error: send group notification failed: %s', err
          reject err

        resolve resultText

router = express.Router()

validator = sequelize.Validator

# 当前用户创建群组
router.post '/create', (req, res, next) ->
  name      = Utility.xss req.body.name, GROUP_NAME_MAX_LENGTH
  memberIds = req.body.memberIds
  encodedMemberIds = req.body.encodedMemberIds

  Utility.log 'memberIds', memberIds
  Utility.log 'encodedMemberIds', encodedMemberIds

  if not validator.isLength name, GROUP_NAME_MIN_LENGTH, GROUP_NAME_MAX_LENGTH
    return res.status(400).send 'Length of group name is out of limit.'
  if memberIds.length is 1
    return res.status(400).send "Group's member count should be greater than 1 at least."
  if memberIds.length > DEFAULT_MAX_GROUP_MEMBER_COUNT
    return res.status(400).send "Group's member count is out of max group member count limit (#{DEFAULT_MAX_GROUP_MEMBER_COUNT})."

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  GroupMember.getGroupCount currentUserId
  .then (count) ->
    # 检查用户创建的群组数量上限
    if count is MAX_USER_GROUP_OWN_COUNT
      return res.send new APIResult 1000, null, "Current user's group count is out of max user group count limit (#{MAX_USER_GROUP_OWN_COUNT})."

    sequelize.transaction (t) ->
      co ->
        # 创建群组
        group = yield Group.create
          name: name
          portraitUri: ''
          memberCount: memberIds.length
          creatorId: currentUserId
          timestamp: timestamp
        ,
          transaction: t

        Utility.log 'Group %s created by %s', group.id, currentUserId
          # 创建群组成员关系
        yield GroupMember.bulkUpsert group.id, memberIds, timestamp, t, currentUserId

        return group
    .then (group) ->
      # 更新版本号（时间戳）
      DataVersion.updateGroupMemberVersion group.id, timestamp
      .then ->
        # 调用融云接口创建群组，如果创建失败，后续用计划任务同步
        rongCloud.group.create encodedMemberIds, Utility.encodeId(group.id), name, (err, resultText) ->
          if err
            Utility.logError 'Error: create group failed on IM server, error: %s', err

          result = JSON.parse resultText
          success = result.code is 200

          if success
            Session.getCurrentUserNickname currentUserId, User
            .then (nickname) ->
              sendGroupNotification currentUserId,
                group.id,
                GROUP_OPERATION_CREATE,
                operatorNickname: nickname
                targetGroupName: name
                timestamp: timestamp
          else
            Utility.logError 'Error: create group failed on IM server, code: %s', result.code

            # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
            GroupSync.upsert
              syncInfo: success
              syncMember: success
            ,
              where:
                groupId: group.id

        # 无论调用融云接口成功与否，都返回创建群组成功
        res.send new APIResult 200, Utility.encodeResults id: group.id
  .catch next

# 当前用户添加群组成员
router.post '/add', (req, res, next) ->
  groupId   = req.body.groupId
  memberIds = req.body.memberIds
  encodedGroupId   = req.body.encodedGroupId
  encodedMemberIds = req.body.encodedMemberIds

  Utility.log 'Group %s add members %j by user %s', groupId, memberIds, Session.getCurrentUserId req

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Group.getInfo groupId
  .then (group) ->
    if not group
      return res.status(404).send 'Unknown group.'

    memberCount = group.memberCount + memberIds.length

    if memberCount > group.maxMemberCount
      return res.status(400).send "Group's member count is out of max group member count limit (#{group.maxMemberCount})."

    sequelize.transaction (t) ->
      Promise.all [
        # 更新群组成员数
        Group.update
          memberCount: memberCount
          timestamp: timestamp
        ,
          where:
            id: groupId
          transaction: t
      ,
        # 创建群组成员关系
        GroupMember.bulkUpsert groupId, memberIds, timestamp, t
      ]
    .then ->
      # 更新版本号（时间戳）
      DataVersion.updateGroupMemberVersion groupId, timestamp
      .then ->
        # 调用融云接口加入群组，如果创建失败，后续用计划任务同步
        rongCloud.group.join encodedMemberIds, encodedGroupId, group.name, (err, resultText) ->
          if err
            Utility.logError 'Error: join group failed on IM server, error: %s', err

          result = JSON.parse resultText
          success = result.code is 200

          if success
            User.getNicknames memberIds
            .then (nicknames) ->
              Session.getCurrentUserNickname currentUserId, User
              .then (nickname) ->
                sendGroupNotification currentUserId,
                  groupId,
                  GROUP_OPERATION_ADD,
                  operatorNickname: nickname
                  targetUserIds: encodedMemberIds
                  targetUserDisplayNames: nicknames
                  timestamp: timestamp
          else
            Utility.logError 'Error: join group failed on IM server, code: %s', result.code

            # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
            GroupSync.upsert
              syncMember: true
            ,
              where:
                groupId: group.id

        res.send new APIResult 200
  .catch next

# 当前用户加入某群组
router.post '/join', (req, res, next) ->
  groupId = req.body.groupId
  encodedGroupId = req.body.encodedGroupId

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Group.getInfo groupId
  .then (group) ->
    if not group
      return res.status(404).send 'Unknown group.'

    memberCount = group.memberCount + 1

    if memberCount > group.maxMemberCount
      return res.status(400).send "Group's member count is out of max group member count limit (#{group.maxMemberCount})."

    sequelize.transaction (t) ->
      Promise.all [
        # 更新群组成员数
        Group.update
          memberCount: memberCount
          timestamp: timestamp
        ,
          where:
            id: groupId
          transaction: t
      ,
        # 创建群组成员关系
        GroupMember.bulkUpsert groupId, [currentUserId], timestamp, t
      ]
    .then ->
      # 更新版本号（时间戳）
      DataVersion.updateGroupMemberVersion groupId, timestamp
      .then ->
        encodedIds = [Utility.encodeId(currentUserId)]

        # 调用融云接口加入群组，如果创建失败，后续用计划任务同步
        rongCloud.group.join encodedIds, encodedGroupId, group.name, (err, resultText) ->
          if err
            Utility.logError 'Error: join group failed on IM server, error: %s', err

          result = JSON.parse resultText
          success = result.code is 200

          if success
            Session.getCurrentUserNickname currentUserId, User
            .then (nickname) ->
              sendGroupNotification currentUserId,
                groupId,
                GROUP_OPERATION_ADD,
                operatorNickname: nickname
                targetUserIds: encodedIds
                targetUserDisplayNames: [nickname]
                timestamp: timestamp
          else
            Utility.logError 'Error: join group failed on IM server, code: %s', result.code

            # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
            GroupSync.upsert
              syncMember: true
            ,
              where:
                groupId: group.id

        res.send new APIResult 200
  .catch next

# 创建者将用户踢出群组
router.post '/kick', (req, res, next) ->
  groupId   = req.body.groupId
  memberIds = req.body.memberIds
  encodedGroupId   = req.body.encodedGroupId
  encodedMemberIds = req.body.encodedMemberIds

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  # 踢出只剩自己了，群组也不解散

  # 不能将创建者自己踢出群组
  if _.contains memberIds, currentUserId
    return res.status(400).send 'Can not kick yourself.'

  Group.getInfo groupId
  .then (group) ->
    if not group
      return res.status(404).send 'Unknown group.'

    if group.creatorId isnt currentUserId
      return res.status(403).send 'Current user is not group creator.'

    # 要踢出群组的 memberId 不在群组里
    GroupMember.findAll
      where:
        groupId: groupId
      attributes: [
        'memberId'
      ]
    .then (groupMembers) ->
      if groupMembers.length is 0
        throw new Error 'Group member should not be empty, please check your database.'

      isKickNonMember = false
      emptyMemberIdFlag = false

      memberIds.forEach (memberId) ->
        emptyMemberIdFlag = true if Utility.isEmpty memberId
        isKickNonMember = groupMembers.every (member) ->
          memberId isnt member.memberId

      # 如果群组成员中有空项目，直接返回错误请求
      if emptyMemberIdFlag
        return res.status(400).send 'Empty memberId.'

      if isKickNonMember
        return res.status(400).send 'Can not kick none-member from the group.'

      User.getNicknames memberIds
      .then (nicknames) ->
        Session.getCurrentUserNickname currentUserId, User
        .then (nickname) ->
          sendGroupNotification currentUserId,
            groupId,
            GROUP_OPERATION_KICKED,
            operatorNickname: nickname
            targetUserIds: encodedMemberIds
            targetUserDisplayNames: nicknames
            timestamp: timestamp
          .then ->
            # 调用融云接口退出群组，如果创建失败，后续用计划任务同步
            rongCloud.group.quit encodedMemberIds, encodedGroupId, (err, resultText) ->
              if err
                Utility.logError 'Error: quit group failed on IM server, error: %s', err

              result = JSON.parse resultText
              success = result.code is 200

              if not success
                Utility.logError 'Error: quit group failed on IM server, code: %s', result.code

                return res.status(500).send 'Quit failed on IM server.'

                # # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
                # GroupSync.upsert
                #   syncMember: true
                # ,
                #   where:
                #     groupId: group.id

              sequelize.transaction (t) ->
                Promise.all [
                  Group.update
                    memberCount: group.memberCount - memberIds.length
                    timestamp: timestamp
                  ,
                    where:
                      id: groupId
                    transaction: t
                ,
                  GroupMember.update
                    isDeleted: true
                    timestamp: timestamp
                  ,
                    where:
                      groupId: groupId
                      memberId:
                        $in: memberIds
                    transaction: t
                ]
              .then ->
                # 更新版本号（时间戳）
                DataVersion.updateGroupMemberVersion groupId, timestamp
                .then ->
                  res.send new APIResult 200
  .catch next

# 用户自行退出群组
router.post '/quit', (req, res, next) ->
  groupId = req.body.groupId
  encodedGroupId = req.body.encodedGroupId

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Group.getInfo groupId
  .then (group) ->
    if not group
      return res.status(404).send 'Unknown group.'

    # 获取群组成员列表
    GroupMember.findAll
      where:
        groupId: groupId
      attributes: [
        'memberId'
      ]
    .then (groupMembers) ->
      isInGroup = groupMembers.some (groupMember) ->
        groupMember.memberId is currentUserId

      if not isInGroup
        return res.status(403).send 'Current user is not group member.'

      encodedMemberIds = [Utility.encodeId(currentUserId)]

      Session.getCurrentUserNickname currentUserId, User
      .then (nickname) ->
        sendGroupNotification currentUserId,
          groupId,
          GROUP_OPERATION_QUIT,
          operatorNickname: nickname
          targetUserIds: encodedMemberIds
          targetUserDisplayNames: [nickname]
          timestamp: timestamp
        .then ->
          # 调用融云接口退出群组，如果创建失败，后续用计划任务同步
          rongCloud.group.quit encodedMemberIds, encodedGroupId, (err, resultText) ->
            if err
              Utility.logError 'Error: quit group failed on IM server, error: %s', err

            result = JSON.parse resultText
            success = result.code is 200

            if not success
              Utility.logError 'Error: quit group failed on IM server, code: %s', result.code

              return res.status(500).send 'Quit failed on IM server.'

              # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
              # GroupSync.upsert
              #   syncMember: true
              # ,
              #   where:
              #     groupId: group.id

            resultMessage = null

            sequelize.transaction (t) ->
              # 如果不是创建者，正常退出群组
              if group.creatorId isnt currentUserId
                resultMessage = 'Quit.'

                Promise.all [
                  Group.update
                    memberCount: group.memberCount - 1
                    timestamp: timestamp
                  ,
                    where:
                      id: groupId
                    transaction: t
                ,
                  GroupMember.update
                    isDeleted: true
                    timestamp: timestamp
                  ,
                    where:
                      groupId: groupId
                      memberId: currentUserId
                    transaction: t
                ]
              # 如果是创建者，且群成员大于一，需要将创建者移交给群组里的第二个成员
              else if group.memberCount > 1
                newCreatorId = null
                # 寻找第一个不是群组创建者的人
                groupMembers.some (groupMember) ->
                  if groupMember.memberId isnt currentUserId
                    # 将群组创建者改为第一个不是群组创建者的人
                    newCreatorId = groupMember.memberId
                    return true
                  else
                    return false

                resultMessage = 'Quit and group owner transfered.'

                Promise.all [
                  Group.update
                    memberCount: group.memberCount - 1
                    creatorId: newCreatorId
                    timestamp: timestamp
                  ,
                    where:
                      id: groupId
                    transaction: t
                ,
                  GroupMember.update
                    role: GROUP_MEMBER
                    isDeleted: true
                    timestamp: timestamp
                  ,
                    where:
                      groupId: groupId
                      memberId: currentUserId
                    transaction: t
                ,
                  GroupMember.update
                    role: GROUP_CREATOR
                    timestamp: timestamp
                  ,
                    where:
                      groupId: groupId
                      memberId: newCreatorId
                    transaction: t
                ]
              # 群组里没有人了，解散群组
              else
                resultMessage = 'Quit and group dismissed.'

                Promise.all [
                  Group.update
                    memberCount: 0
                    timestamp: timestamp
                  ,
                    where:
                      id: groupId
                    transaction: t
                ,
                  Group.destroy
                    where:
                      id: groupId
                    transaction: t
                ,
                  GroupMember.update
                    isDeleted: true
                    timestamp: timestamp
                  ,
                    where:
                      groupId: groupId
                    transaction: t
                ]
            .then ->
              # 更新版本号（时间戳）
              DataVersion.updateGroupMemberVersion groupId, timestamp
              .then ->
                res.send new APIResult 200, null, resultMessage
  .catch next

# 创建者解散群组
router.post '/dismiss', (req, res, next) ->
  groupId = req.body.groupId
  encodedGroupId = req.body.encodedGroupId

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  Session.getCurrentUserNickname currentUserId, User
  .then (nickname) ->
    sendGroupNotification currentUserId,
      groupId,
      GROUP_OPERATION_DISMISS,
      operatorNickname: nickname
      timestamp: timestamp
    .then ->
      # 调用融云接口创建群组，如果创建失败，后续用计划任务同步
      rongCloud.group.dismiss Utility.encodeId(currentUserId), encodedGroupId, (err, resultText) ->
        if err
          Utility.logError 'Error: dismiss group failed on IM server, error: %s', err

        result = JSON.parse resultText
        success = result.code is 200

        if not success
          Utility.logError 'Error: dismiss group failed on IM server, code: %s', result.code

          return res.send new APIResult 500, null, 'Quit failed on IM server.'

          # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
          GroupSync.upsert
            dismiss: true
          ,
            where:
              groupId: groupId

        sequelize.transaction (t) ->
          Group.update
            memberCount: 0
          ,
            where:
              id: groupId
              creatorId: currentUserId
            transaction: t
          .then ([affectedCount]) ->
            Utility.log 'affectedCount', affectedCount
            # 只有创建者才可以解散群组
            if affectedCount is 0
              throw new HTTPError 'Unknown group or not creator.', 400
              #return res.status(400).send 'Unknown group or not creator.'

            Promise.all [
              Group.destroy
                where:
                  id: groupId
                transaction: t
            ,
              GroupMember.update
                isDeleted: true
                timestamp: timestamp
              ,
                where:
                  groupId: groupId
                transaction: t
            ]
        .then ->
          # 更新版本号（时间戳）
          DataVersion.updateGroupMemberVersion groupId, timestamp
          .then ->
            res.send new APIResult 200
        .catch (err) ->
          if err instanceof HTTPError
            return res.status(err.statusCode).send err.message
  .catch next

# 创建者为群组重命名
router.post '/rename', (req, res, next) ->
  groupId = req.body.groupId
  name    = Utility.xss req.body.name, GROUP_NAME_MAX_LENGTH
  encodedGroupId = req.body.encodedGroupId

  if not validator.isLength name, GROUP_NAME_MIN_LENGTH, GROUP_NAME_MAX_LENGTH
    return res.status(400).send 'Length of name invalid.'

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  # 更新数据库
  Group.update
    name: name
    timestamp: timestamp
  ,
    where:
      id: groupId
      creatorId: currentUserId
  .then ([affectedCount]) ->
    # 只有创建者才可以重命名
    if affectedCount is 0
      return res.status(400).send 'Unknown group or not creator.'

    # 更新版本号（时间戳）
    DataVersion.updateGroupVersion groupId, timestamp
    .then ->
      # 调用融云服务器刷新群组信息
      rongCloud.group.refresh encodedGroupId, name, (err, resultText) ->
        if err
          Utility.logError 'Error: refresh group info failed on IM server, error: %s', err

        result = JSON.parse resultText
        success = result.code is 200

        if not success
          Utility.logError 'Error: refresh group info failed on IM server, code: %s', result.code

        # 在数据库中标记成功失败状态，如果失败，后续计划任务同步
        GroupSync.upsert
          syncInfo: true
        ,
          where:
            groupId: groupId

      Session.getCurrentUserNickname currentUserId, User
      .then (nickname) ->
        sendGroupNotification currentUserId,
          groupId,
          GROUP_OPERATION_RENAME,
          operatorNickname: nickname
          targetGroupName: name
          timestamp: timestamp

      res.send new APIResult 200
  .catch next

# 创建者设置群组头像地址
router.post '/set_portrait_uri', (req, res, next) ->
  groupId     = req.body.groupId
  portraitUri = Utility.xss req.body.portraitUri, PORTRAIT_URI_MAX_LENGTH

  if not validator.isURL portraitUri, { protocols: ['http', 'https'], require_protocol: true }
    return res.status(400).send 'Invalid portraitUri format.'
  if not validator.isLength portraitUri, PORTRAIT_URI_MIN_LENGTH, PORTRAIT_URI_MAX_LENGTH
    return res.status(400).send 'Length of portraitUri invalid.'

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  # 更新数据库
  Group.update
    portraitUri: portraitUri
    timestamp: timestamp
  ,
    where:
      id: groupId
      creatorId: currentUserId
  .then ([affectedCount]) ->
    # 只有创建者才可以设置群组头像
    if affectedCount is 0
      return res.status(400).send 'Unknown group or not creator.'

    # 更新版本号（时间戳）
    DataVersion.updateGroupVersion groupId, timestamp
    .then ->
      res.send new APIResult 200
  .catch next

# 修改自己的群组昵称
router.post '/set_display_name', (req, res, next) ->
  groupId = req.body.groupId
  displayName = Utility.xss req.body.displayName, GROUP_MEMBER_DISPLAY_NAME_MIN_LENGTH

  if (displayName isnt '') and not validator.isLength displayName, GROUP_MEMBER_DISPLAY_NAME_MIN_LENGTH, GROUP_MEMBER_DISPLAY_NAME_MAX_LENGTH
    return res.status(400).send 'Length of display name invalid.'

  currentUserId = Session.getCurrentUserId req
  timestamp = Date.now()

  GroupMember.update
    displayName: displayName
    timestamp: timestamp
  ,
    where:
      groupId: groupId
      memberId: currentUserId
  .then ([affectedCount]) ->
    if affectedCount is 0
      return res.status(404).send 'Unknown group.'
    # 更新版本号（时间戳）
    DataVersion.updateGroupMemberVersion currentUserId, timestamp
    .then ->
      res.send new APIResult 200
  .catch next

# 获取群组信息
router.get '/:id', (req, res, next) ->
  groupId = req.params.id

  groupId = Utility.decodeIds groupId

  currentUserId = Session.getCurrentUserId req

  Group.findById groupId,
    attributes: [
      'id'
      'name'
      'portraitUri'
      'memberCount'
      'maxMemberCount'
      'creatorId'
      'deletedAt'
    ]
    paranoid: false
  .then (group) ->
    if not group
      return res.status(404).send 'Unknown group.'

    # ADD: 不做判断了，因为离开群组的用户有些情况下也需要群组信息
    # 群组成员才可以查看群组信息
    # GroupMember.count
    #   where:
    #     groupId: groupId
    #     memberId: currentUserId
    # .then (count) ->
    #   if count is 0
    #     return res.status(403).send 'Only group member can get group info.'

    res.send new APIResult 200, Utility.encodeResults group, ['id', 'creatorId']
  .catch next

# 获取群组成员
router.get '/:id/members', (req, res, next) ->
  groupId = req.params.id

  groupId = Utility.decodeIds groupId

  currentUserId = Session.getCurrentUserId req

  GroupMember.findAll
    where:
      groupId: groupId
    attributes: [
      'displayName'
      'role'
      'createdAt'
      'updatedAt'
    ]
    include:
      model: User
      attributes: [
        'id'
        'nickname'
        'portraitUri'
      ]
  .then (groupMembers) ->
    # 群组不存在
    if groupMembers.length is 0
      return res.status(404).send 'Unknown group.'

    # 当前用户是否在群组中的标识
    isInGroup = groupMembers.some (groupMember) ->
      groupMember.user.id is currentUserId

    if not isInGroup
      return res.status(403).send 'Only group member can get group member info.'

    res.send new APIResult 200, Utility.encodeResults groupMembers, [['user', 'id']]
  .catch next

module.exports = router

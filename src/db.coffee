Sequelize = require 'sequelize'
co        = require 'co'
_         = require 'underscore'

Config    = require './conf'
Utility   = require('./util/util').Utility
HTTPError = require('./util/util').HTTPError

GROUP_CREATOR = 0
GROUP_MEMBER  = 1

sequelize = new Sequelize Config.DB_NAME, Config.DB_USER, Config.DB_PASSWORD,
  host: Config.DB_HOST
  port: Config.DB_PORT
  dialect: 'mysql'
  timezone: '+08:00'
  logging: null

userClassMethods =
  getNicknames: (userIds) ->
    User.findAll
      where:
        id:
          $in: userIds
      attributes: [
        'id'
        'nickname'
      ]
    .then (users) ->
      userIds.map (userId) ->
        _.find(users, (user) ->
          user.id is userId
        ).nickname

  getNickname: (userId) ->
    User.findById userId,
      attributes: [
        'nickname'
      ]
    .then (user) ->
      if user
        user.nickname
      else
        null

  checkUserExists: (userId) ->
    User.count
      where:
        id: userId
    .then (count) ->
      Promise.resolve count is 1
    .catch (err) ->
      Promise.reject err

  checkPhoneAvailable: (region, phone) ->
    User.count
      where:
        region: region
        phone: phone
    .then (count) ->
      Promise.resolve count is 0
    .catch (err) ->
      Promise.reject err
  # checkUsernameAvailable: (username) ->
  #   User.count
  #     where:
  #       username: username
  #   .then (count) ->
  #     Promise.resolve count is 0
  #   .catch (err) ->
  #     Promise.reject err

friendshipClassMethods =
  getInfo: (userId, friendId) ->
    Friendship.findOne
      where:
        userId: userId
        friendId: friendId
      attributes: [
        'id'
        'status'
        'message'
        'timestamp'
        'updatedAt'
      ]

groupClassMethods =
  getInfo: (groupId) ->
    Group.findById groupId,
      attributes: [
        'id'
        'name'
        'creatorId'
        'memberCount'
      ]

groupMemberClassMethods =
  bulkUpsert: (groupId, memberIds, timestamp, transaction, creatorId) ->
    co ->
      groupMembers = yield GroupMember.unscoped().findAll
        where:
          groupId: groupId
        attributes: [
          'memberId'
          'isDeleted'
        ]

      createGroupMembers = []
      updateGroupMemberIds = []
      roleFlag = GROUP_MEMBER

      # 检查是否包含空项目和重复项，并构建创建和更新数据
      memberIds.forEach (memberId) ->
        if Utility.isEmpty memberId
          throw new HTTPError 'Empty memberId in memberIds.', 400

        roleFlag = GROUP_CREATOR if memberId is creatorId

        isUpdateMember = false

        groupMembers.some (groupMember) ->
          if memberId is groupMember.memberId
            if not groupMember.isDeleted
              throw new HTTPError 'Should not add exist member to the group.', 400
            isUpdateMember = true
          else
            false

        if isUpdateMember
          updateGroupMemberIds.push memberId
        else
          createGroupMembers.push
            groupId: groupId
            memberId: memberId
            role: if memberId is creatorId then GROUP_CREATOR else GROUP_MEMBER
            timestamp: timestamp

      if creatorId isnt undefined and roleFlag is GROUP_MEMBER
        throw new HTTPError 'Creator is not in memeber list.', 400

      # 更新群组成员关系
      if updateGroupMemberIds.length > 0
        yield GroupMember.unscoped().update
          role: GROUP_MEMBER
          isDeleted: false
          timestamp: timestamp
        ,
          where:
            groupId: groupId
            memberId:
              $in: updateGroupMemberIds
          transaction: transaction

      # 创建群组成员关系
      yield GroupMember.bulkCreate createGroupMembers, transaction: transaction

  getGroupCount: (userId) ->
    GroupMember.count
      where:
        memberId: userId

dataVersionClassMethods =
  updateUserVersion: (userId, timestamp) ->
    DataVersion.update userVersion: timestamp,
      where:
        userId: userId

  updateBlacklistVersion: (userId, timestamp) ->
    DataVersion.update blacklistVersion: timestamp,
      where:
        userId: userId

  updateFriendshipVersion: (userId, timestamp) ->
    DataVersion.update friendshipVersion: timestamp,
      where:
        userId: userId

  updateAllFriendshipVersion: (userId, timestamp) ->
    # ONL FOR MYSQL
    sequelize.query 'UPDATE data_versions d JOIN friendships f ON d.userId = f.userId AND f.friendId = ? AND f.status = 20 SET d.friendshipVersion = ?', replacements: [userId, timestamp], type: Sequelize.QueryTypes.UPDATE

  updateGroupVersion: (groupId, timestamp) ->
    # ONL FOR MYSQL
    sequelize.query 'UPDATE data_versions d JOIN group_members g ON d.userId = g.memberId AND g.groupId = ? AND g.isDeleted = 0 SET d.groupVersion = ?', replacements: [groupId, timestamp], type: Sequelize.QueryTypes.UPDATE

  updateGroupMemberVersion: (groupId, timestamp) ->
    # ONL FOR MYSQL
    sequelize.query 'UPDATE data_versions d JOIN group_members g ON d.userId = g.memberId AND g.groupId = ? AND g.isDeleted = 0 SET d.groupVersion = ?, d.groupMemberVersion = ?', replacements: [groupId, timestamp, timestamp], type: Sequelize.QueryTypes.UPDATE

verificationCodeClassMethods =
  getByToken: (token) ->
    VerificationCode.findOne
      where:
        token: token
      attributes: [
        'region'
        'phone'
      ]

  getByPhone: (region, phone) ->
    VerificationCode.findOne
      where:
        region: region
        phone: phone
      attributes: [
        'sessionId'
        'token'
        'updatedAt'
      ]

# 用户模型
User = sequelize.define 'users',
  id:             { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  # username:      { type: Sequelize.STRING(64), allowNull: false, unique: true, comment: '最小 4 个字' }
  region:         { type: Sequelize.STRING(5), allowNull: false, validate: { isInt: true } }
  phone:          { type: Sequelize.STRING(11), allowNull: false, validate: { isInt: true } }
  nickname:       { type: Sequelize.STRING(32), allowNull: false }
  portraitUri:    { type: Sequelize.STRING(256), allowNull: false, defaultValue: '' }
  passwordHash:   { type: Sequelize.CHAR(40), allowNull: false }
  passwordSalt:   { type: Sequelize.CHAR(4), allowNull: false }
  rongCloudToken: { type: Sequelize.STRING(256), allowNull: false, defaultValue: '' }
  groupCount:     { type: Sequelize.INTEGER.UNSIGNED, allowNull: false, defaultValue: 0 }
  timestamp:      { type: Sequelize.BIGINT, allowNull: false, defaultValue: 0, comment: '时间戳（版本号）' }
  ,
    classMethods: userClassMethods
    paranoid: true
    indexes: [
      unique: true
      fields: ['region', 'phone']
    ]

# 黑名单模型
Blacklist = sequelize.define 'blacklists',
  id:         { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  userId:     { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  friendId:   { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  status:     { type: Sequelize.BOOLEAN, allowNull: false, comment: 'true: 拉黑' }
  timestamp:  { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '时间戳（版本号）' }
  ,
    indexes: [
      unique: true
      fields: ['userId', 'friendId']
    ,
      method: 'BTREE'
      fields: ['userId', 'timestamp']
    ]

Blacklist.belongsTo User, { foreignKey: 'friendId', constraints: false }

# 好友关系模型
Friendship = sequelize.define 'friendships',
  id:           { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  userId:       { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  friendId:     { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  displayName:  { type: Sequelize.STRING(32), allowNull: false, defaultValue: '' }
  message:      { type: Sequelize.STRING(64), allowNull: false }
  status:       { type: Sequelize.INTEGER.UNSIGNED, allowNull: false, comment: '10: 请求, 11: 被请求, 20: 同意, 21: 忽略, 30: 被删除' }
  timestamp:    { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '时间戳（版本号）' }
  ,
    classMethods: friendshipClassMethods
    indexes: [
      unique: true
      fields: ['userId', 'friendId']
    ,
      method: 'BTREE'
      fields: ['userId', 'timestamp']
    ]

Friendship.belongsTo User, { foreignKey: 'friendId', constraints: false }

# 群组关系模型
Group = sequelize.define 'groups',
  id:             { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  name:           { type: Sequelize.STRING(32), allowNull: false, comment: '最小 2 个字' }
  portraitUri:    { type: Sequelize.STRING(256), allowNull: false, defaultValue: '' }
  memberCount:    { type: Sequelize.INTEGER.UNSIGNED, allowNull: false, defaultValue: 0 }
  maxMemberCount: { type: Sequelize.INTEGER.UNSIGNED, allowNull: false, defaultValue: 500 }
  creatorId:      { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  timestamp:      { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '时间戳（版本号）' }
  ,
    classMethods: groupClassMethods
    paranoid: true
    indexes: [
      unique: true
      fields: ['id', 'timestamp']
    ]

# 群组成员模型
GroupMember = sequelize.define 'group_members',
  id:           { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  groupId:      { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  memberId:     { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  displayName:  { type: Sequelize.STRING(32), allowNull: false, defaultValue: '' }
  role:         { type: Sequelize.INTEGER.UNSIGNED, allowNull: false, comment: '0: 创建者, 1: 普通成员' }
  isDeleted:    { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false }
  timestamp:    { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '时间戳（版本号）' }
  ,
    classMethods: groupMemberClassMethods
    defaultScope:
      where:
        isDeleted: false
    indexes: [
      unique: true
      fields: ['groupId', 'memberId', 'isDeleted']
    ,
      method: 'BTREE'
      fields: ['memberId', 'timestamp']
    ]

GroupMember.belongsTo User, { foreignKey: 'memberId', constraints: false }
GroupMember.belongsTo Group, { foreignKey: 'groupId', constraints: false }

# 群组同步任务模型
GroupSync = sequelize.define 'group_syncs',
  groupId:    { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true }
  syncInfo:   { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false, comment: '是否需要同步群组信息到 IM 服务器' }
  syncMember: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false, comment: '是否需要同步群组成员到 IM 服务器' }
  dismiss:    { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false, comment: '是否需要在 IM 服务端成功解散群组' }
  ,
    timestamps: false

# 数据版本号模型
DataVersion = sequelize.define 'data_versions',
  userId:             { type: Sequelize.INTEGER.UNSIGNED, allowNull: false, primaryKey: true }
  userVersion:        { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '用户信息时间戳（版本号）' }
  blacklistVersion:   { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '黑名单时间戳（版本号）' }
  friendshipVersion:  { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '好友关系时间戳（版本号）' }
  groupVersion:       { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '群组信息时间戳（版本号）' }
  groupMemberVersion: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, defaultValue: 0, comment: '群组关系时间戳（版本号）' }
  ,
    classMethods: dataVersionClassMethods
    timestamps: false

# 验证码模型
VerificationCode = sequelize.define 'verification_codes',
  id:         { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  region:     { type: Sequelize.STRING(5), allowNull: false, primaryKey: true }
  phone:      { type: Sequelize.STRING(11), allowNull: false, primaryKey: true }
  sessionId:  { type: Sequelize.STRING(32), allowNull: false }
  token:      { type: Sequelize.UUID, allowNull: false, defaultValue: Sequelize.UUIDV1, unique: true }
  ,
    classMethods: verificationCodeClassMethods
    indexes: [
      unique: true
      fields: ['region', 'phone']
    ]

# 登录日志
LoginLog = sequelize.define 'login_logs',
  id:           { type: Sequelize.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true }
  userId:       { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  ipAddress:    { type: Sequelize.INTEGER.UNSIGNED, allowNull: false }
  os:           { type: Sequelize.STRING(64), allowNull: false }
  osVersion:    { type: Sequelize.STRING(64), allowNull: false }
  carrier:      { type: Sequelize.STRING(64), allowNull: false }
  device:       { type: Sequelize.STRING(64) }
  manufacturer: { type: Sequelize.STRING(64) }
  userAgent:    { type: Sequelize.STRING(256) }
  ,
    updatedAt: false

module.exports = [sequelize, User, Blacklist, Friendship, Group, GroupMember, GroupSync, DataVersion, VerificationCode, LoginLog]

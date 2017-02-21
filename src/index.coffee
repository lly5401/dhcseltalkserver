express           = require 'express'
cookieParser      = require 'cookie-parser'
bodyParser        = require 'body-parser'
compression       = require 'compression'
cors              = require 'cors'

Config            = require './conf'
Session           = require './util/session'
Utility           = require('./util/util').Utility
HTTPError         = require('./util/util').HTTPError
userRouter        = require './routes/user'         # 引用用户相关接口
friendshipRouter  = require './routes/friendship'   # 引用好友相关接口
groupRouter       = require './routes/group'        # 引用群组相关接口
miscRouter        = require './routes/misc'         # 引用其他功能接口

if (env = process.env.NODE_ENV) isnt 'development' and env isnt 'production'
  console.log "Error: NODE_ENV must be set to 'development' or 'production'."
  return process.exit()

app = express()

app.use cors                # 使用 CORS，支持跨域
  origin: Config.CORS_HOSTS
  credentials: true
app.use compression()       # 使用内容压缩
app.use cookieParser()      # 使用 Cookie 解析器
app.use bodyParser.json()   # 使用 Body 解析器

# 身份验证
authentication = (req, res, next) ->
  # 不需要验证身份的路径
  for reqPath in [
    '/misc/demo_square'
    '/misc/latest_update'
    '/misc/client_version'
    '/user/login'
    '/user/register'
    '/user/reset_password'
    '/user/send_code'
    '/user/verify_code'
    '/user/get_sms_img_code'
    '/user/check_username_available'
    '/user/check_phone_available'
  ]
    if req.path is reqPath
      if req.body.password
        body = JSON.stringify(req.body).replace(/"password":".*?"/, '"password":"**********"')
      else
        body = JSON.stringify req.body

      Utility.logPath 'Request: %s %s %s', req.method, req.originalUrl, body

      return next() # 跳过验证

  currentUserId = Session.getCurrentUserId req

  # 无法获取用户 Id，即表示没有登录
  # if not currentUserId
  #   return res.status(403).send 'Not loged in.'

  Utility.logPath 'Request: User(%s) %s %s %s', currentUserId, req.method, req.originalUrl, JSON.stringify(req.body)

  next()

# 设置缓存头
cacheControl = (req, res, next) ->
  res.set 'Cache-Control', 'private'

  next()

# 参数预处理
parameterPreprocessor = (req, res, next) ->
  for prop of req.body
    # 参数解码
    if prop.endsWith('Id') or prop.endsWith('Ids')
      req.body['encoded' + prop[0].toUpperCase() + prop.substr(1)] = req.body[prop]
      req.body[prop] = Utility.decodeIds req.body[prop]

    # 检测空参数，屏显名除外
    if Utility.isEmpty(req.body[prop]) and prop isnt 'displayName' and prop isnt 'pushContent'
      return res.status(400).send "Empty #{prop}."

  next()

# 错误处理
errorHandler = (err, req, res, next) ->
  if err instanceof HTTPError
    return res.status(err.statusCode).send err.message

  Utility.logError err

  res.status(500).send err.message || 'Unknown error.'

app.all '*', authentication             # 前置身份验证
app.use parameterPreprocessor           # 参数预处理
app.use cacheControl                    # 缓存处理
app.use '/user', userRouter             # 加载用户相关接口
app.use '/friendship', friendshipRouter # 加载好友相关接口
app.use '/group', groupRouter           # 加载群组相关接口
app.use '/misc', miscRouter             # 加载其他功能接口
app.use errorHandler                    # 错误处理

# 开启端口监听
server = app.listen Config.SERVER_PORT, ->
  console.log 'SealTalk Server listening at http://%s:%s in %s mode.',
    server.address().address,
    server.address().port,
    app.get('env')

module.exports = app

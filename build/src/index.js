var Config, HTTPError, Session, Utility, app, authentication, bodyParser, cacheControl, compression, cookieParser, cors, env, errorHandler, express, friendshipRouter, groupRouter, miscRouter, parameterPreprocessor, server, userRouter;

express = require('express');

cookieParser = require('cookie-parser');

bodyParser = require('body-parser');

compression = require('compression');

cors = require('cors');

Config = require('./conf');

Session = require('./util/session');

Utility = require('./util/util').Utility;

HTTPError = require('./util/util').HTTPError;

userRouter = require('./routes/user');

friendshipRouter = require('./routes/friendship');

groupRouter = require('./routes/group');

miscRouter = require('./routes/misc');

if ((env = process.env.NODE_ENV) !== 'development' && env !== 'production') {
  console.log("Error: NODE_ENV must be set to 'development' or 'production'.");
  return process.exit();
}

app = express();

app.use(cors({
  origin: Config.CORS_HOSTS,
  credentials: true
}));

app.use(compression());

app.use(cookieParser());

app.use(bodyParser.json());

authentication = function(req, res, next) {
  var body, currentUserId, i, len, ref, reqPath;
  ref = ['/misc/demo_square', '/misc/latest_update', '/misc/client_version', '/user/login', '/user/register', '/user/reset_password', '/user/send_code', '/user/verify_code', '/user/get_sms_img_code', '/user/check_username_available', '/user/check_phone_available'];
  for (i = 0, len = ref.length; i < len; i++) {
    reqPath = ref[i];
    if (req.path === reqPath) {
      if (req.body.password) {
        body = JSON.stringify(req.body).replace(/"password":".*?"/, '"password":"**********"');
      } else {
        body = JSON.stringify(req.body);
      }
      Utility.logPath('Request: %s %s %s', req.method, req.originalUrl, body);
      return next();
    }
  }
  currentUserId = Session.getCurrentUserId(req);
  Utility.logPath('Request: User(%s) %s %s %s', currentUserId, req.method, req.originalUrl, JSON.stringify(req.body));
  return next();
};

cacheControl = function(req, res, next) {
  res.set('Cache-Control', 'private');
  return next();
};

parameterPreprocessor = function(req, res, next) {
  var prop;
  for (prop in req.body) {
    if (prop.endsWith('Id') || prop.endsWith('Ids')) {
      req.body['encoded' + prop[0].toUpperCase() + prop.substr(1)] = req.body[prop];
      req.body[prop] = Utility.decodeIds(req.body[prop]);
    }
    if (Utility.isEmpty(req.body[prop]) && prop !== 'displayName' && prop !== 'pushContent') {
      return res.status(400).send("Empty " + prop + ".");
    }
  }
  return next();
};

errorHandler = function(err, req, res, next) {
  if (err instanceof HTTPError) {
    return res.status(err.statusCode).send(err.message);
  }
  Utility.logError(err);
  return res.status(500).send(err.message || 'Unknown error.');
};

app.all('*', authentication);

app.use(parameterPreprocessor);

app.use(cacheControl);

app.use('/user', userRouter);

app.use('/friendship', friendshipRouter);

app.use('/group', groupRouter);

app.use('/misc', miscRouter);

app.use(errorHandler);

server = app.listen(Config.SERVER_PORT, function() {
  return console.log('SealTalk Server listening at http://%s:%s in %s mode.', server.address().address, server.address().port, app.get('env'));
});

module.exports = app;

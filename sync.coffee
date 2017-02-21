[sequelize] = require './src/db.coffee'

console.log 'Drop all schemas.'

# 删除数据库结构
sequelize.drop()

console.log 'Sync all schemas.'

# 同步数据库结构
sequelize.sync(force: true)
  .then ->
    console.log 'All done!'
  .catch (err) ->
    console.log err

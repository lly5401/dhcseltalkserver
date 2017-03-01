module.exports = (grunt) ->

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')


    clean:

      release:
        src: [
          'dist/*'
        ]

    copy:

      release:
        files: [
          expand: true
          cwd: 'build/src'
          src: '**/*.*'
          dest: 'dist'
        ]



    nodemon:
      # Start dev environment.
      dev:
        script: 'build/src'
        options:
          nodeArgs: ['--harmony'] # Support ES6 when node version < 4.0

  # These plugins provide necessary tasks.
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-nodemon'


  grunt.registerTask 'release', [
    'clean'
    'copy:release'
  ]

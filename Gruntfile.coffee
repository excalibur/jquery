###*
 * grunt任务配置
###
'use strict'
LIVERELOAD_PORT = 35729
lrSnippet = require('connect-livereload') 
	port: LIVERELOAD_PORT
mountFolder = (connect, dir)-> 
    connect.static require('path').resolve dir

excluded = []
included = []

module.exports = (grunt)->
	# 显示任务时间
	require('time-grunt')(grunt)
	# 载入grunt tasks
	require('load-grunt-tasks')(grunt)

	jqueryConfig =
		dist:'dist'
		tmp:'.tmp'
		src:'src'
		test:'test'
	# grunt 配置
	grunt.initConfig 
		jquery: jqueryConfig
		watch: 
			options: 
			    nospawn: true
			coffee: 
			    files: ['<%=jquery.src%>/{,*/}*.coffee']
			    tasks: ['coffee:development']
			livereload: 
			    options: 
			        livereload: LIVERELOAD_PORT
			    files: [
			        'app/{,*/}*.html'
			        '.tmp/js/{,*/}*.js'
			    ]
    	# 配置coffee
		coffee:
			options:
			    bare: true
			development:
				expand: true
				cwd: '<%=jquery.src%>'
				src: ['{,*/}*.coffee']
				dest: '<%=jquery.tmp%>'
				ext: '.js'
		connect: 
            options:
                port: 9000
                hostname: 'localhost'
            livereload: 
                options: 
                    middleware: (connect)->
                        [
                            lrSnippet,
                            mountFolder(connect, '.tmp')
                            mountFolder(connect, 'app')
                        ]

        open: 
            server: 
                path: 'http://<%= connect.options.hostname %>:<%= connect.options.port %>'
        clean: 
            server: '.tmp'


		# 验证javascript格式
		jshint: 
			src:
				options: 
					jshintrc: "src/.jshintrc"
					ignores:[
						"src/intro.js"
						"src/outro.js"
					]
				src: [
			    	'src/{,*/}*.js'
			    ]
        # concat任务用于合并模块
		# concat:{}
		# copy任务 主要copy 源码中的js文件
		copy:
			main:
				expand: true
				cwd: '<%= jquery.src %>'
				src: '{,*/}*.js'
				dest: '<%= jquery.tmp %>'
		# requirejs 配置
		requirejs:
			compile:
				options:
					baseUrl: '<%=jquery.src%>'
					name: "jquery"
					out: '<%=jquery.dist%>/jquery.js'
					optimize: "none"
					# dir: 'dist'
					findNestedDependencies: true
					skipSemiColonInsertion: true
					wrap: 
						startFile: '<%=jquery.tmp%>/intro.js'
						endFile: '<%=jquery.tmp%>/outro.js'
					rawText: {}
					# 定义没有在 src目录下的模块
					# paths:{}

					# 包括模块 自定义是根据jquery依赖
					include: included
					# 排除模块
					exclude: excluded
					# 排除AMD申明定义，因为最后压缩以后都在一个文件，不存在模块依赖。
					onBuildWrite: (name, path, contents)->
						# 匹配每个模块的最后
						rdefineEnd = /\}\);[^}\w]*$/
						# 排除intro、outro
						if not /.\/(intro.js)|(outro.js)$/.test path
							# 如果位于var文件夹下 采用这样的替换策略 
							if /.\/var\//.test path
								contents = contents.replace(/define\([\w\W]*?return/, "var #{/var\/([\w-]+)/.exec(name)[1]} ="
								).replace rdefineEnd, "" 
							else if /^sizzle$/.test name
								contents = "var Sizzle =\n" + contents.replace( /\/\/\s*EXPOSE[\w\W]*\/\/\s*EXPOSE/, "return Sizzle;" )
							else 
								if name isnt "jquery"
									contents = contents.replace( /\s*return\s+[^\}]+(\}\);[^\w\}]*)$/, "$1" ).replace( /\s*exports\.\w+\s*=\s*\w+;/g, "" )
								contents = contents.replace( /define\([^{]*?{/, "" ).replace( rdefineEnd, "" )
								contents = contents.replace( /\/\*\s*ExcludeStart\s*\*\/[\w\W]*?\/\*\s*ExcludeEnd\s*\*\//ig, "" ).replace( /\/\/\s*BuildExclude\n\r?[\w\W]*?\n\r?/ig, "" )
								contents = contents.replace( /define\(\[[^\]]+\]\)[\W\n]+$/, "" )
						contents

	grunt.registerTask 'server', (target)->
	    grunt.task.run [
	        'clean:server'
	        'coffee:server'
	        'connect:livereload'
	        'open'
	        'watch'
	    ]

	grunt.registerTask 'build'
	,"构建源文件，移除AMD定义，可以采用'-'排除不需要的模块，'+'来增加打包模块" 
	,(targets)->
		console.log targets
			
	# 仿制javascript自定义打包
	grunt.registerTask 'custom'
	,"构建源文件，移除AMD定义，可以采用'-'排除不需要的模块，'+'来增加打包模块"
	,()->
		args = [].slice.call arguments
		modules = if args.length then args[ 0 ].split(",") else ""
		grunt.log.writeln "自定义打包模块 构建...\n"
		for m in modules
			if m.indexOf('-') is 0
				excluded.push m.slice 1
			else
				if m.indexOf('+') is 0
					included.push m.slice 1
				else
					included.push m
		grunt.task.run [
			"requirejs"
			# "pre-uglify"
			# "uglify"
			# "dist"
		]			

   
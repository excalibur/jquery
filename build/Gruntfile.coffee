###*
 * grunt任务配置
###
'use strict'
LIVERELOAD_PORT = 35729
lrSnippet = require('connect-livereload') 
	port: LIVERELOAD_PORT
mountFolder = (connect, dir)-> 
    connect.static require('path').resolve dir



module.exports = (grunt)->
	# 显示任务时间
	require('time-grunt')(grunt)
	# 载入grunt tasks
	require('load-grunt-tasks')(grunt)

	# grunt 配置
	grunt.initConfig 
		watch: 
			options: 
			    nospawn: true
			coffee: 
			    files: ['coffee/{,*/}*.coffee']
			    tasks: ['coffee:server']
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
			server:
				expand: true
				cwd: 'coffee'
				src: ['{,*/}*.coffee']
				dest: '.tmp/js'
				ext: '.js'
			dist:
				expand: true
				cwd: 'coffee'
				src: ['{,*/}*.coffee']
				dest: '.tmp/js'
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


        # concat任务用于合并模块
		concat:
			dist:
				options:
					process: (src, filepath)->
						# 修改模块命名
						if filepath is 'src/a.js'
							console.log src
						src
				files:
					'dist/jquery.js':[
						'src/intro.js'
						'src/{,*/}*.js'
						'src/outro.js'
					]
		# requirejs 配置
		requirejs:
			compile:
				options:
					baseUrl: "src"
					name: "jquery"
					out: "dist/jquery.js"
					optimize: "none"
					# dir: 'dist'
					findNestedDependencies: true
					skipSemiColonInsertion: true
					wrap: 
						startFile: "src/intro.js"
						endFile: "src/outro.js"
					rawText: {}
					# 包括模块 自定义是根据jquery依赖
					# include: [
					# ]
					# 排除模块
					# exclude:[
					# 	"var/arr"
					# ]
					# 排除AMD申明定义，因为最后压缩以后都在一个文件，不存在模块依赖。
					onBuildWrite: (name, path, contents)->
						console.log path
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

	grunt.registerMultiTask 'build'
	,"构建源文件，移除AMD定义，可以采用'-'排除不需要的模块，'+'来增加打包模块" 
	,()->
		flag
		index
		excluded = []
		included = []
		done = @async()
		flags = @flags
		optIn = flags[ "*" ]
		name = @data.dest
		minimum = @data.minimum
		removeWith = @data.removeWith
		version = grunt.config "pkg.version"
		excludeList = (list, prepend)->
			if list
				prepend = if prepend then prepend + "/" else ""
				for module in array
					if module is 'var'
						excludeList( fs.readdirSync( srcFolder + prepend + module ), prepend + module );
						return
					if prepend
							if not(module = /([\w-\/]+)\.js$/.exec( module ))
								return;
							module = prepend + module[1]
					if excluded.indexOf( module ) is -1
							excluder "-" + module 
		excluder = (flag)->
			m = /^(\+|\-|)([\w\/-]+)$/.exec flag
			exclude = m[ 1 ] is "-"
			module = m[ 2 ]
			if exclude
				if minimum.indexOf( module ) is -1
					if excluded.indexOf( module ) is -1
						grunt.log.writeln flag
						excluded.push module
						try 
							excludeList fs.readdirSync(srcFolder + module), module
						catch e
							grunt.verbose.writeln e
							
					excludeList removeWith[module]
				else
					grunt.log.error "Module \"" + module + "\" is a mimimum requirement."
					if module is "selector"
						grunt.log.error "If you meant to replace Sizzle, use -sizzle instead."
			else
				grunt.log.writeln flag
				included.push module			
			
		if process.env.COMMIT
			version += " " + process.env.COMMIT	

		delete flags[ "*" ]
		for flag in flags
			excluder flag 
		
		if (index = excluded.indexOf( "sizzle" )) > -1
			config.rawText.selector = "define(['./selector-native']);"
			excluded.splice index, 1


		grunt.verbose.writeflags excluded, "Excluded"
		grunt.verbose.writeflags included, "Included"	

		if excluded.length
			version += " -" + excluded.join( ",-" )
			grunt.config.set "pkg.version", version
			grunt.verbose.writeln "Version changed to " + version
			config.excludeShallow = excluded
		config.include = included

		config.out = (compiled)->
			compiled = compiled.replace(/@VERSION/g, version)
				.replace /@DATE/g, ( new Date() ).toISOString().replace( /:\d+\.\d+Z$/, "Z" )
			grunt.file.write name, compiled

		if not optIn
			config.rawText.jquery = "define([" + (if included.length then included.join(",") else "") + "]);"

		requirejs.optimize config, ( response )->
			grunt.verbose.writeln response
			grunt.log.ok  "File '" + name + "' created."
			done()
		, ( err )->
			done( err )

	grunt.registerTask 'custom',()->
    	args = [].slice.call arguments
    	modules = if args.length then args[ 0 ].replace( /,/g, ":" ) else ""
    	grunt.log.writeln "自定义打包模块 构建...\n"
    	grunt.task.run [
    		"build:*:*:" + modules
    		# "pre-uglify"
    		# "uglify"
    		# "dist"
    	]			

   
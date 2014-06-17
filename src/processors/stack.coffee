# https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error/Stack
# https://code.google.com/p/v8/wiki/JavaScriptStackTraceApi
# http://msdn.microsoft.com/en-us/library/ie/hh699850%28v=vs.94%29.aspx
# http://ie.microsoft.com/testdrive/Browser/ExploreErrorStack/

rules = [
  {
    name: 'v8',
    re: /// ^
      \s*
      at\s
      (.+?)\s       # function
      \(
        (?:
          (?:
            (.+):  # file
            (\d+): # line
            (\d+)  # column
          )
          |
          (.+)
        )
      \)
    $ ///,
    fn: (m) ->
      return {
        function: m[1],
        file: m[2] or m[5],
        line: m[3] and parseInt(m[3], 10) or 0,
        column: m[4] and parseInt(m[4], 10) or 0,
      }
  },

  {
    name: 'firefox30',
    re: /// ^
      (.*)@  # function
      (.+):  # file
      (\d+): # line
      (\d+)  # column
    $ ///,
    fn: (m) ->
      return {
        function: m[1],
        file: m[2],
        line: parseInt(m[3], 10),
        column: parseInt(m[4], 10),
      }
  }

  {
    name: 'firefox14',
    re: /// ^
      (.*)@ # function
      (.+): # file
      (\d+) # line
    $ ///,
    fn: (m, i, e) ->
      if i == 0
        column = e.columnNumber or 0
      else
        column = 0
      return {
        function: m[1],
        file: m[2],
        line: parseInt(m[3], 10),
        column: column,
      }
  },

  # TODO: which browsers generate such stack?
  {
    name: 'todo',
    re: /// ^
      \s+at\s
      (.+):     # file
      (\d+):    # line
      (\d+)     # column
    $ ///,
    fn: (m) ->
      return {
        function: '',
        file: m[1],
        line: parseInt(m[2], 10),
        column: parseInt(m[3], 10),
      }
  },

  {
    name: 'default',
    re: /.+/,
    fn: (m) ->
      console?.debug?("airbrake: can't parse", m[0])
      return {
        function: m[0],
        file: '',
        line: 0,
        column: 0,
      }
  }
]

typeMessageRe = /// ^
  \S+:\s # type
  .+     # message
$ ///

processor = (e, cb) ->
  processorName = ''
  stack = e.stack or ''
  lines = stack.split('\n')

  backtrace = []
  for line, i in lines
    if line == ''
      continue

    for rule in rules
      m = line.match(rule.re)
      if not m
        continue

      processorName = rule.name
      backtrace.push(rule.fn(m, i, e))

      break

  if processorName == 'v8' and backtrace.length > 0 and backtrace[0].function.match(typeMessageRe)
    backtrace = backtrace[1..]

  if backtrace.length == 0 and (e.fileName? or e.lineNumber? or e.columnNumber?)
    backtrace.push({
      function: '',
      file: e.fileName or '',
      line: parseInt(e.lineNumber, 10) or 0,
      column: parseInt(e.columnNumber, 10) or 0,
    })

  if e.message?
    msg = e.message
  else
    msg = String(e)

  if e.name?
    type = e.name
    msg = type + ': ' + msg
  else
    type = ''

  return cb(processorName, {
    'type': type,
    'message': msg,
    'backtrace': backtrace,
  })


module.exports = processor

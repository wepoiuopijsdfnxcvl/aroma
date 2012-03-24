
cjson = require"cjson"

msg_id = 0
msg_responders = {}

async_scope = nil

post_message = (o) ->
  o = cjson.encode o if type(o) == "table"
  nacl.post_message o

post_and_respond = (msg, fn) ->
  id = msg_id
  msg_id += 1
  msg_responders[id] = fn
  post_message {"request", id, msg }

printer = (channel="std_out") ->
  (...) ->
    args = {...}
    str = table.concat [tostring s for s in *args], "\t"
    post_message { channel, str }

async_print = printer"std_out"
ap = async_print
async_print_err = printer"std_err"
async_err = (msg) ->
  async_print_err debug.traceback msg, 2
  coroutine.yield "error"

async_assert = (thing, msg="Assertion failed") ->
  if thing == nil
    async_err msg
  else
    thing

-- need the thread
async_require = (module_name) ->
  mod = package.loaded[module_name]
  return mod if mod

  loader = if package.preload[module_name]
    package.preload[module_name]
  else
    thread = coroutine.running!
    post_and_respond { "require", module_name }, (msg) ->
      status, code = unpack msg
      if status == "error"
        async_print_err code
      else
        coroutine.resume thread, code

    code = coroutine.yield "wait"
    async_assert loadstring code, module_name

  setfenv loader, getfenv 2
  mod = loader module_name
  package.loaded[module_name] = mod
  mod

async_scope = setmetatable {
    print: async_print
    require: async_require
    error: async_err
  }, {
    __index: _G
  }


nacl.handle_message = (msg) ->
  error "unknown msg: " .. tostring(msg) if type(msg) != "string"
  print ">>", msg\sub 1, 120

  msg = cjson.decode msg

  switch msg[1]
    when "execute"
      fn, err = loadstring msg[2], "execute"
      if not fn
        async_print_err err
      else
        thread = nil
        fn = setfenv fn, async_scope
        thread = coroutine.create fn

        success, err = coroutine.resume thread
        if not success
          async_print_err err

    when "response"
      _, id, data = unpack msg
      handler = msg_responders[id]
      if handler
        msg_responders[id] = nil
        handler data
    else
      error "Don't know how to handle message: " .. (msg[1] or msg)

nacl.init = {
  graphics: =>
    @newImage = (url) ->
      thread = coroutine.running!
      post_and_respond { "image", url }, (msg) ->
        status, bytes, width, height = unpack msg
        if status == "success"
          coroutine.resume thread, nacl.image_from_byte_string bytes, width, height
        else
          async_print_err bytes

      coroutine.yield "wait"
}

-- nacl.init_all = (aroma) -> -- called when aroma is first created

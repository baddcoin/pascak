/*
  examples/chat_gui.pas

  Browser-based public chat with polling.

  Run:   pascak_noASTnet examples/chat_gui.pas
  Opens: http://localhost:18320/
  Open multiple browser tabs/windows to see live sync.

  Demonstrates:
    - gui.bind for send / poll
    - Shared state (messages array) across connections
    - Polling pattern for "push" (no WS broadcast needed)

  Note: for true real-time, add gui.broadcast (backlog). Polling at
  500ms is fine for demos and low-traffic chat.
*/

begin
  sys.execWhitelist(["termux-open-url", "xdg-open", "open"]);

  var h := gui.create(18320, 18321, "Pascak Chat");
  if h < 0 then begin
    println("gui.create failed");
    sys.exit(1);
  end;

  // Shared state
  var messages := [];
  var MAX_MSGS := 200;

  gui.bind(h, "send", lambda args : begin
    var user := args[0];
    var text := args[1];
    if typeOf(text) != "string" then return false;
    if len(trim(text)) == 0 then return false;
    push(messages, {
      "user": user,
      "text": trim(text),
      "ts": toInteger(time.now())
    });
    // Cap
    while len(messages) > MAX_MSGS do
      delete(messages, 0);
    return true;
  end);

  gui.bind(h, "poll", lambda args : begin
    var since := toInteger(args[0]);
    if since < 0 then since := 0;
    if since > len(messages) then since := len(messages);
    return {
      "messages": messages[since:],
      "next": len(messages)
    };
  end);

  gui.serve(h,
    '<!DOCTYPE html>' +
    '<html><head><title>Pascak Chat</title><style>' +
    'body{font-family:sans-serif;max-width:800px;margin:0 auto;height:100vh;display:flex;flex-direction:column;}' +
    'header{padding:16px;background:#2a8;color:#fff;font-size:20px;font-weight:bold;}' +
    '#msgs{flex:1;overflow-y:auto;padding:16px;background:#f9f9f9;}' +
    '.msg{margin-bottom:8px;padding:8px 12px;background:#fff;border-radius:6px;border:1px solid #eee;}' +
    '.user{font-weight:bold;color:#2a8;}' +
    '.ts{color:#999;font-size:11px;margin-left:8px;}' +
    'footer{padding:12px;background:#eee;display:flex;gap:8px;}' +
    '#inp{flex:1;padding:10px;font-size:16px;border:1px solid #ccc;border-radius:4px;}' +
    'button{padding:10px 20px;font-size:16px;cursor:pointer;border:0;border-radius:4px;background:#2a8;color:#fff;}' +
    '</style></head><body>' +
    '<header>Pascak Chat</header>' +
    '<div id="msgs"></div>' +
    '<footer>' +
    '<input id="user" style="width:120px;" value="guest"/>' +
    '<input id="inp" placeholder="Type a message..." onkeypress="if(event.key===\'Enter\')send()"/>' +
    '<button onclick="send()">Send</button>' +
    '</footer>' +
    '<script>' +
    'var cursor = 0;' +
    'function fmt(ts){' +
    '  var d=new Date(ts*1000);' +
    '  return d.toLocaleTimeString();' +
    '}' +
    'function esc(s){var d=document.createElement("div");d.textContent=s;return d.innerHTML;}' +
    'async function send(){' +
    '  var u=document.getElementById("user").value||"guest";' +
    '  var i=document.getElementById("inp");' +
    '  var v=i.value.trim(); if(!v)return;' +
    '  await window.pascak.call("send",[u,v]); i.value="";' +
    '  poll();' +
    '}' +
    'async function poll(){' +
    '  try{' +
    '    var r = await window.pascak.call("poll",[cursor]);' +
    '    for(var m of r.messages){' +
    '      var d=document.createElement("div");' +
    '      d.className="msg";' +
    '      d.innerHTML="<span class=user>"+esc(m.user)+"</span>"+' +
    '                  "<span class=ts>"+fmt(m.ts)+"</span>"+' +
    '                  "<div>"+esc(m.text)+"</div>";' +
    '      document.getElementById("msgs").appendChild(d);' +
    '    }' +
    '    if(r.messages.length>0)' +
    '      document.getElementById("msgs").scrollTop = 1e9;' +
    '    cursor = r.next;' +
    '  }catch(e){console.error(e);}' +
    '}' +
    'setInterval(poll, 500);' +
    'poll();' +
    '</script></body></html>');

  var r := gui.start(h);
  if not r then begin
    println("gui.start failed");
    gui.close(h);
    sys.exit(1);
  end;

  println("Chat GUI: http://localhost:18320/");
  println("Open multiple browser tabs to chat.");
  if not gui.open(h) then
    println("  open browser manually");

  setTimeout(lambda : begin
    println("Closing (10 min timeout)");
    gui.close(h);
    sys.exit(0);
  end, 600000);

  gui.run(h);
end.

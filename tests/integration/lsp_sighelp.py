import subprocess, json

PASCAK = "/data/data/com.termux/files/home/pascak_test"
SRC = '''function add(a, b) begin
  return a + b;
end.

begin
  println(add(1, 2));
end.
'''

def frame(obj):
    body = json.dumps(obj).encode()
    return f"Content-Length: {len(body)}\r\n\r\n".encode() + body

def read_msg(p):
    hdr = b""
    while b"\r\n\r\n" not in hdr:
        ch = p.stdout.read(1)
        if not ch: return None
        hdr += ch
    n = 0
    for line in hdr.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            n = int(line.split(b":")[1].strip())
    body = p.stdout.read(n)
    return json.loads(body)

def read_response(p, req_id):
    while True:
        msg = read_msg(p)
        if msg is None: return None
        if msg.get("id") == req_id:
            return msg

p = subprocess.Popen([PASCAK, "--lsp"], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)

p.stdin.write(frame({"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}))
p.stdin.flush()
r = read_response(p, 1)
caps = r.get("result",{}).get("capabilities",{})
print("=== initialize caps ===")
print("signatureHelpProvider:", caps.get("signatureHelpProvider"))
print()

p.stdin.write(frame({"jsonrpc":"2.0","method":"textDocument/didOpen",
  "params":{"textDocument":{"uri":"file:///t.pas","languageId":"pascak","version":1,"text":SRC}}}))
p.stdin.flush()

FAIL = 0

def sig_at(char, expect_func, expect_active, label):
    global FAIL
    p.stdin.write(frame({"jsonrpc":"2.0","id":100,"method":"textDocument/signatureHelp",
      "params":{"textDocument":{"uri":"file:///t.pas"},"position":{"line":5,"character":char}}}))
    p.stdin.flush()
    r = read_response(p, 100)
    s = r.get("result")
    print(f"--- {label} (char {char}) ---")
    if s:
        label0 = s["signatures"][0]["label"]
        active = s.get("activeParameter")
        print(f"  label: {label0}")
        print(f"  activeParameter: {active}")
        if expect_func:
            ok = (expect_func in label0) and (active == expect_active)
            print(f"  {'PASS' if ok else 'FAIL'}: expect '{expect_func}' active={expect_active}")
            if not ok: FAIL += 1
    else:
        print("  NONE")
        if expect_func is not None:
            print(f"  FAIL: expected '{expect_func}', got NONE")
            FAIL += 1
    print()

sig_at(10, "println", 0, "inside println args, before add")
sig_at(14, "add", 0, "inside add(1|,)")
sig_at(16, "add", 1, "inside add(1, |) after comma")
sig_at(17, "add", 1, "inside add(1, |2)")
sig_at(19, "println", 0, "after add() returns, back in println")

p.stdin.write(frame({"jsonrpc":"2.0","id":200,"method":"textDocument/signatureHelp",
  "params":{"textDocument":{"uri":"file:///t.pas"},"position":{"line":3,"character":0}}}))
p.stdin.flush()
r = read_response(p, 200)
print("--- not in call (line 3) ---")
print("  result:", r.get("result"))
if r.get("result") is not None:
    print("  FAIL: expected None")
    FAIL += 1
print()

p.stdin.write(frame({"jsonrpc":"2.0","id":5,"method":"shutdown","params":{}}))
p.stdin.flush()
read_response(p, 5)
p.stdin.write(frame({"jsonrpc":"2.0","method":"exit"}))
p.stdin.flush()
p.wait(timeout=3)

print(f"=== RESULT: {'FAIL' if FAIL else 'PASS'} ({FAIL} failures) ===")

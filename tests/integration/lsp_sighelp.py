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

# Line 5 (0-based): "  println(add(1, 2));"
# 0-based indices: 0-1 sp, 2-8 println, 9 '(', 10-12 add, 13 '(', 14 '1', 15 ',', 16 sp, 17 '2', 18 ')', 19 ')', 20 ';'

def sig_at(char, label):
    p.stdin.write(frame({"jsonrpc":"2.0","id":100,"method":"textDocument/signatureHelp",
      "params":{"textDocument":{"uri":"file:///t.pas"},"position":{"line":5,"character":char}}}))
    p.stdin.flush()
    r = read_response(p, 100)
    s = r.get("result")
    print(f"--- {label} (char {char}) ---")
    if s:
        print("  label:", s["signatures"][0]["label"])
        print("  params:", [p.get("label") for p in s["signatures"][0].get("parameters",[])])
        print("  activeParameter:", s.get("activeParameter"))
    else:
        print("  NONE")
    print()

sig_at(11, "inside add(1|)")        # before '1' → add, param 0
sig_at(15, "after add(1|, ...")     # before ',' → add, param 0
sig_at(17, "add(1, |2)")            # before '2' → add, param 1
sig_at(10, "println(|)")            # after '(' → println, param 0

# Not in call
p.stdin.write(frame({"jsonrpc":"2.0","id":200,"method":"textDocument/signatureHelp",
  "params":{"textDocument":{"uri":"file:///t.pas"},"position":{"line":3,"character":0}}}))
p.stdin.flush()
r = read_response(p, 200)
print("--- not in call (line 3) ---")
print("  result:", r.get("result"))
print()

p.stdin.write(frame({"jsonrpc":"2.0","id":5,"method":"shutdown","params":{}}))
p.stdin.flush()
read_response(p, 5)
p.stdin.write(frame({"jsonrpc":"2.0","method":"exit"}))
p.stdin.flush()
p.wait(timeout=3)

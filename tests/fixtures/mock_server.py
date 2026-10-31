import h2.config, h2.connection, h2.events, ssl, socket, os, time

PORT = 8443
CERT = os.path.expanduser('~/h2_test/server.crt')
KEY = os.path.expanduser('~/h2_test/server.key')
ENHANCE_N = int(os.environ.get('MOCK_ENHANCE_N', '3'))

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT, KEY)
ctx.set_alpn_protocols(['h2'])

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('127.0.0.1', PORT))
sock.listen(10)
print(f'LISTEN {PORT} enhance_n={ENHANCE_N}', flush=True)

accept_n = 0
while True:
    conn, _ = sock.accept()
    accept_n += 1
    is_enhance = accept_n <= ENHANCE_N
    try:
        tls = ctx.wrap_socket(conn, server_side=True)
    except Exception as e:
        print(f'wrap fail: {e}', flush=True); continue
    print(f'CONN#{accept_n} alpn={tls.selected_alpn_protocol()} enhance={is_enhance}', flush=True)
    config = h2.config.H2Configuration(client_side=False, header_encoding='utf-8')
    h2c = h2.connection.H2Connection(config=config)
    h2c.initiate_connection()
    tls.sendall(h2c.data_to_send())

    while True:
        try:
            data = tls.recv(65535)
        except Exception as e:
            print(f'recv exc: {e}', flush=True); break
        if not data:
            break
        events = h2c.receive_data(data)
        responded = False
        for ev in events:
            if isinstance(ev, h2.events.RequestReceived):
                hdrs = dict(ev.headers)
                path = hdrs.get(':path', '?')
                print(f'  REQ#{accept_n} stream={ev.stream_id} path={path}', flush=True)
                if is_enhance:
                    print(f'  >> GOAWAY ENHANCE_YOUR_CALM (conn #{accept_n} <= {ENHANCE_N})', flush=True)
                    h2c.close_connection(error_code=11)
                    tls.sendall(h2c.data_to_send())
                    responded = True
                    break
                else:
                    body = b'OK-after-retry'
                    print(f'  >> 200 OK body={body!r}', flush=True)
                    h2c.send_headers(ev.stream_id, [
                        (':status', '200'),
                        ('content-type', 'text/plain'),
                        ('content-length', str(len(body))),
                    ])
                    h2c.send_data(ev.stream_id, body, end_stream=True)
                    tls.sendall(h2c.data_to_send())
                    responded = True
        if responded:
            break
    try: tls.close()
    except: pass
